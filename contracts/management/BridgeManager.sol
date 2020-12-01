// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../common/SafeMath.sol";
import "../ownership/Ownable.sol";
import "./ManagerConstants.sol";

// BridgeManager implements the Fantom CrossChain Bridge management
// contract.
contract BridgeManager is Initializable, Ownable, ManagerConstants {
    using SafeMath for uint256;

    // Validator represents a Bridge validator record
    struct Validator {
        // status pf the Validator
        uint256 status;

        // milestones in the Validator's life
        uint256 createdTime;
        uint256 createdEpoch;
        uint256 deactivatedTime;
        uint256 deactivatedEpoch;

        // authorized address of the Validator
        address auth;
    }

    // getValidator represents the list of validators by their IDs
    mapping(uint256 => Validator) public getValidator;

    // getValidatorID represents the relation between a Validator address
    // and the ID of the Validator.
    mapping(address => uint256) public getValidatorID;

    // lastValidatorID represents the ID of the latest validator;
    // it also represents the total number of Validators since a new validator
    // is assigned the next available ID and zero ID is skipped.
    uint256 public lastValidatorID;

    // totalStake represents the total amount of staked tokens across
    // all active Validators.
    uint256 public totalStake;

    // validatorMetadata represents the metadata of a Validator by the ID;
    // please check documentation for the expected metadata structure (JSON object)
    mapping(uint256 => bytes) public validatorMetadata;

    // initialize sets the initial state of the bridge manager
    function initialize(address[] memory genesisValidators) external initializer {
        // initialize the owner
        Ownable.initialize(msg.sender);

        // create the first genesis set of validators
        for (uint256 i = 0; i < genesisValidators.length; i++) {
            _createValidator(genesisValidators[i]);
        }
    }
}
