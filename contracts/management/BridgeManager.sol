// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../common/Decimal.sol";
import "../common/SafeMath.sol";
import "../common/IERC20.sol";
import "../common/SafeERC20.sol";
import "../ownership/Ownable.sol";
import "../utils/Version.sol";
import "./ManagerConstants.sol";
import "./RewardDistribution.sol";

// BridgeManager implements the Fantom CrossChain Bridge management
// contract.
contract BridgeManager is Initializable, Ownable, Context, ManagerConstants, RewardDistribution, Version {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // ------------------------------
    // structs
    // ------------------------------

    // Validator represents a Bridge validator record
    struct Validator {
        // status pf the Validator
        uint256 status;
        uint256 receivedStake;

        // milestones in the Validator's life
        uint256 createdTime;
        uint256 deactivatedTime;

        // authorized address of the Validator
        address auth;
    }

    // UnstakingRequest represents a structure describing
    // a request for (partial) stake removal.
    struct UnstakingRequest {
        uint256 time;
        uint256 amount;
    }

    // ------------------------------
    // state variables storage space
    // ------------------------------

    // getValidator represents the list of validators by their IDs
    mapping(uint256 => Validator) public getValidator;

    // validatorMetadata stores encoded validator information in case
    // validators wanted to present their details to the community
    mapping(uint256 => bytes) public validatorMetadata;

    // getValidatorID represents the relation between a Validator address
    // and the ID of the Validator.
    mapping(address => uint256) public getValidatorID;

    // getDelegation represents the amount of stake granted by a staker address
    // to the given validator.
    // Map: Staker => ValidatorID => Amount
    mapping(address => mapping(uint256 => uint256)) public getDelegation;

    // getUnstakingRequest represents the structure of un-staking requests
    // being placed from the given staker address to the given validator.
    // Each request must have a unique requestID identifier under which
    // the unstaking is registered.
    // Map: Staker => ValidatorID => RequestID => UnstakingRequest struct
    mapping(address => mapping(uint256 => mapping(uint256 => UnstakingRequest))) public getUnstakingRequest;

    // lastValidatorID represents the ID of the latest validator;
    // it also represents the total number of Validators since a new validator
    // is assigned the next available ID and zero ID is skipped.
    uint256 public lastValidatorID;

    // totalSlashedStake represents the total amount of staked tokens
    // slashed by the protocol due to validators malicious behaviour.
    uint256 public totalSlashedStake;

    // totalStake represents the total amount of staked tokens across
    // all active Validators.
    uint256 totalStake;

    // stakingToken represents the address of an ERC20 token used for staking
    // on the Bridge.
    IERC20 public stakingToken;

    // validatorMetadata represents the metadata of a Validator by the ID;
    // please check documentation for the expected metadata structure (JSON object)
    mapping(uint256 => bytes) public validatorMetadata;

    // ----------------------------
    // events
    // ----------------------------
    event UpdatedValidatorWeight(uint256 indexed validatorID, uint256 weight);

    // ------------------------------
    // init & reset state logic
    // ------------------------------

    // initialize sets the initial state of the bridge manager creating the genesis set
    // of bridge validators and assigning the contract owner and tokens
    function initialize(address stToken, address rwToken, address[] memory gnsValidators) external initializer {
        // initialize the owner
        Ownable.initialize(msg.sender);

        // setup the stake token
        stakingToken = IERC20(stToken);

        // setup rewards distribution
        _initRewards(rwToken, initialRewardRate());

        // create the first genesis set of validators
        // we don't handle staking here, the stake
        // for this genesis batch will be added later through stake() call
        for (uint256 i = 0; i < gnsValidators.length; i++) {
            _createValidator(gnsValidators[i]);
        }
    }

    // ------------------------------
    // interface
    // ------------------------------

    // createValidator allows a new candidate to sign up as a validator
    function createValidator(uint256 stake) external {
        // make the validator record
        _createValidator(msg.sender);

        // register the validator stake
        _stake(_sender(), lastValidatorID, stake);
    }

    // stake increases the stake of the given validator identified
    // by the validator ID from the sender by the given amount of staking tokens.
    function stake(uint256 validatorID, uint256 amount) external {
        // validator must exist to receive stake
        require(_validatorExists(validatorID), "BridgeManager: unknown validator");

        // stash accumulated rewards up to this point before the stake amount is updated
        rewardUpdate(_sender(), validatorID);

        // process the stake
        _stake(_sender(), validatorID, amount);
    }

    // setValidatorMetadata stores the new metadata for the validator
    // we don't validate the metadata here, please check the documentation
    // to get the recommended and expected structure of the metadata
    function setValidatorMetadata(bytes calldata metadata) external {
        // validator must exist
        uint256 validatorID = getValidatorID[_sender()];
        require(0 < validatorID, "BridgeManager: unknown validator address");

        // store the new metadata content
        validatorMetadata[validatorID] = metadata;
    }

    // unstake decreases the stake of the given validator identified
    // by the validator ID from the sender by the given amount of staking tokens.
    // User chooses the request ID, which must be unique and not used before.
    function unstake(uint256 validatorID, uint256 amount, uint256 requestID) external {
        // validator must exist to receive stake
        require(_validatorExists(validatorID), "BridgeManager: unknown validator");

        // stash accumulated rewards so the staker doesn't loose any
        rewardUpdate(_sender(), validatorID);

        // process the unstake starter
        _unstake(requestID, _sender(), validatorID, amount);
    }

    // canWithdraw checks if the given un-stake request for the given delegate and validator ID
    // is already unlocked and ready to be withdrawn.
    function canWithdraw(address delegate, uint256 validatorID, uint256 requestID) external view returns (bool) {
        // if the validator dropped its validation account, delegations will unlock sooner
        uint256 requestTime = getUnstakingRequest[delegate][validatorID][requestID].time;
        if (0 < getValidator[validatorID].deactivatedTime && requestTime > getValidator[validatorID].deactivatedTime) {
            requestTime = getValidator[validatorID].deactivatedTime;
        }

        return /* the request must exist */ 0 < requestTime &&
        /* enough time passed from the unstaking */ _now() <= requestTime + unstakePeriodTime();
    }

    // withdraw transfers previously un-staked tokens back to the staker/delegator, if possible
    // this is the place where we check for a slashing, if a validator did not behave correctly
    function withdraw(uint256 validatorID, uint256 requestID) external {
        // make sure the request can be withdrawn
        address delegate = _sender();
        require(canWithdraw(delegate, validatorID, requestID), "BridgeManager: can not withdraw");

        // do the withdraw
        _withdraw(delegate, validatorID, requestID);
    }

    // ------------------------------
    // business logic
    // ------------------------------

    // _createValidator builds up the validator structure
    function _createValidator(address auth) internal {
        // make sure the validator does not exist yet
        require(0 == getValidatorID[auth], "BridgeManager: validator already exists");

        // what will be the new validator id
        uint256 validatorID = ++lastValidatorID;
        getValidatorID[auth] = validatorID;

        // update the validator core record
        getValidator[validatorID].status = STATUS_NEW;
        getValidator[validatorID].createdTime = _now();
        getValidator[validatorID].auth = auth;
    }

    // _stake processes a new stake of a validator
    function _stake(address delegator, uint256 toValidatorID, uint256 amount) internal {
        // make sure the staking request is valid
        require(0 == getValidator[toValidatorID].status & MASK_INACTIVE, "BridgeManager: validator not active");
        require(0 < amount, "BridgeManager: zero stake rejected");
        require(amount <= stakingToken.allowance(delegator, address(this)), "BridgeManager: allowance too low");

        // transfer the stake tokens first
        stakingToken.safeTransferFrom(delegator, address(this), amount);

        // remember the stake and add the staked amount to the validator's total stake value
        // we add the amount using SafeMath to prevent overflow
        totalStake = totalStake.add(amount);
        getDelegation[delegator][toValidatorID] = getDelegation[delegator][toValidatorID].add(amount);
        getValidator[toValidatorID].receivedStake = getValidator[toValidatorID].receivedStake.add(amount);

        // make sure the validator stake is at least the min amount required
        require(minStakeAmount() <= getValidator[toValidatorID].receivedStake, "BridgeManager: stake too low");
        require(_checkDelegatedStakeLimit(toValidatorID), "BridgeManager: delegations limit exceeded");

        // notify the update
        _notifyValidatorWeightChange(toValidatorID);
    }

    // _unstake begins the process of lowering staked tokens by the given amount
    function _unstake(uint256 id, address delegator, uint256 toValidatorID, uint256 amount) internal {
        // validate the request
        require(0 < amount, "BridgeManager: zero un-stake rejected");
        require(amount <= getDelegation[delegator][toValidatorID], "BridgeManager: not enough staked");
        require(0 == getUnstakingRequest[delegator][toValidatorID][id].amount, "BridgeManager: request ID already in use");

        // update the staking picture
        // we can subtract directly since we already tested the request validity and underflow can not happen
        getDelegation[delegator][toValidatorID] -= amount;
        getValidator[toValidatorID].receivedStake -= amount;
        totalStake -= amount;

        // check the remained stake validity and/or validator deactivation condition
        require(_checkDelegatedStakeLimit(toValidatorID) || 0 == _selfStake(toValidatorID), "BridgeManager: delegations limit exceeded");
        if (0 == _selfStake(toValidatorID)) {
            _deactivateValidator(toValidatorID);
        }

        // add the request record
        getUnstakingRequest[delegator][toValidatorID][id].amount = amount;
        getUnstakingRequest[delegator][toValidatorID][id].time = _now();

        // notify the update
        _notifyValidatorWeightChange(toValidatorID);
    }

    // _withdraw transfers previously un-staked tokens back to the staker/delegator, if possible
    // this is the place where we check for a slashing, if a validator did not behave correctly
    function _withdraw(address delegate, uint256 validatorID, uint256 requestID) internal {
        // get the request amount and drop the request; we don't need it anymore
        uint256 amount = getUnstakingRequest[delegate][validatorID][requestID].amount;
        delete getUnstakingRequest[delegate][validatorID][requestID];

        // do we slash the stake?
        if (0 == getValidator[validatorID].status & STATUS_ERROR) {
            // transfer tokens to the delegate
            stakingToken.safeTransfer(delegate, amount);
        } else {
            // we don't transfer anything and just add the stake to total slash
            totalSlashedStake = totalSlashedStake.add(amount);
        }
    }

    // _validatorExists performs a check for a validator existence
    function _validatorExists(uint256 validatorID) view internal returns (bool) {
        return getValidator[validatorID].status > 0;
    }

    // _isSelfStake checks if the given stake is actually an initial stake of the validator.
    function _isSelfStake(address delegator, uint256 toValidatorID) internal view returns (bool) {
        return getValidatorID[delegator] == toValidatorID;
    }

    // _selfStake returns the amount of tokens staked by the validator himself
    function _selfStake(uint256 validatorID) internal view returns (uint256) {
        return getDelegation[getValidator[validatorID].auth][validatorID];
    }

    // _checkDelegatedStakeLimit verifies if the 3rd party delegation does not exceed
    // delegation limit defined as a ratio between self stake of the validator
    // and sum of delegation.
    function _checkDelegatedStakeLimit(uint256 validatorID) internal view returns (bool) {
        return getValidator[validatorID].receivedStake <= _selfStake(validatorID).mul(maxDelegatedRatio()).div(Decimal.unit());
    }

    // _deactivateValidator sets the validator account as withdrawn, if active
    // inactive validator accounts can not be deactivated and trying to do so will revert
    function _deactivateValidator(uint256 validatorID) internal {
        // validator must exist and be active
        require(0 == getValidator[validatorID].status & MASK_INACTIVE, "BridgeManager: invalid validator state");

        // set withdrawn status
        getValidator[validatorID].status = getValidator[validatorID].status | STATUS_WITHDRAWN;
        getValidator[validatorID].deactivatedTime = _now();
    }

    // _notifyValidatorWeightChange notifies a change of the validation power
    // of the given validator. Clients listening for this notification can act
    // accordingly.
    function _notifyValidatorWeightChange(uint256 validatorID) internal {
        // check for validator existence
        require(_validatorExists(validatorID), "BridgeManager: unknown validator");

        // calculate the new weight of the validator; if the validator
        // is not available for whatever reason, the new weight will be zero
        uint256 weight = getValidator[validatorID].receivedStake;
        if (getValidator[toValidatorID].status & MASK_INACTIVE != 0) {
            weight = 0;
        }

        // emit the event for the validator
        emit UpdatedValidatorWeight(validatorID, weight);
    }

    // ------------------------------
    // tooling
    // ------------------------------

    // getTotalStake returns the total amount of staked tokens for the reward
    // distribution calculation.
    function getStakeTotal() public view returns (uint256) {
        return totalStake;
    }

    // getStakeBy returns the amount of staked tokens of a specific staker/validator combo
    // for the reward distribution calculation.
    function getStakeBy(address staker, uint256 validatorID) internal returns (uint256) {
        return getDelegation[staker][validatorID];
    }

    // isStakeJailed returns jail status of the given stake.
    function isStakeJailed(address staker, uint256 validatorID) public view returns (bool) {
        return (getValidator[validatorID].status & STATUS_ERROR != 0);
    }
}
