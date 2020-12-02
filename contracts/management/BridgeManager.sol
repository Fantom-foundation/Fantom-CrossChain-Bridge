// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../common/SafeMath.sol";
import "../common/IERC20.sol";
import "../common/SafeERC20.sol";
import "../ownership/Ownable.sol";
import "../utils/Version.sol";
import "./ManagerConstants.sol";

// BridgeManager implements the Fantom CrossChain Bridge management
// contract.
contract BridgeManager is Initializable, Ownable, ManagerConstants, Version {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

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

    // getValidator represents the list of validators by their IDs
    mapping(uint256 => Validator) public getValidator;

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

    // totalStake represents the total amount of staked tokens across
    // all active Validators.
    uint256 public totalStake;

    // stakingToken represents the address of an ERC20 token used for staking
    // on the Bridge.
    IERC20 public stakingToken;

    // validatorMetadata represents the metadata of a Validator by the ID;
    // please check documentation for the expected metadata structure (JSON object)
    mapping(uint256 => bytes) public validatorMetadata;

    // initialize sets the initial state of the bridge manager creating the genesis set
    // of bridge validators and assigning the contract owner and staking token
    function initialize(address sToken, address[] memory gnsValidators) external initializer {
        // initialize the owner
        Ownable.initialize(msg.sender);

        // setup the token
        stakingToken = IERC20(sToken);

        // create the first genesis set of validators
        // we don't handle staking here, the stake
        // for this genesis batch will be added later through stake() call
        for (uint256 i = 0; i < gnsValidators.length; i++) {
            _createValidator(gnsValidators[i]);
        }
    }

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
        require(getValidator[validatorID].status > 0, "BridgeManager: unknown validator");

        // process the stake
        _stake(_sender(), validatorID, amount);
    }

    // _createValidator builds up the validator structure
    function _createValidator(address auth) internal {
        // make sure the validator does not exist yet
        require(getValidatorID[auth] == 0, "BridgeManager: validator already exists");

        // what will be the new validator id
        uint256 validatorID = ++lastValidatorID;
        getValidatorID[auth] = validatorID;

        // update the validator core record
        getValidator[validatorID].status = STATUS_NEW;
        getValidator[validatorID].createdTime = _now();
        getValidator[validatorID].auth = auth;
    }

    // _stake processes a new stake of a validator
    function _stake(address sender, uint256 toValidator, uint256 amount) internal {
        // make sure the validator is not inactive
        require(getValidator[toValidator].status & MASK_INACTIVE == 0, "BridgeManager: validator not active");

        // verify we can pull the stake tokens from the staker
        require(amount <= stakingToken.allowance(sender, address(this)), "BridgeManager: allowance too low");

        // transfer the stake tokens first
        stakingToken.safeTransferFrom(sender, address(this), amount);

        // remember the stake and add the staked amount to the validator's total stake value
        getDelegation[sender][toValidator] = getDelegation[sender][toValidator].add(amount);
        getValidator[toValidator].receivedStake = getValidator[toValidator].receivedStake.add(amount);

        // make sure the validator stake is at least the min amount required
        require(minStakeAmount() <= getValidator[toValidator].receivedStake, "BridgeManager: stake too low");
    }

    // _isSelfStake checks if the given stake is actually an initial stake of the validator.
    function _isSelfStake(address delegator, uint256 toValidatorID) internal view returns (bool) {
        return getValidatorID[delegator] == toValidatorID;
    }

    // _sender returns the address of the current trx sender
    function _sender() internal view returns (address) {
        return msg.sender;
    }

    // _now returns the current timestamp as available to the contract call
    function _now() internal view returns (uint256) {
        return block.timestamp;
    }
}
