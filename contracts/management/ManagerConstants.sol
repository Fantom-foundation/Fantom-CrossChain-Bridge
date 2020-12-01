pragma solidity ^0.5.0;

// ManagerConstants implements constants used in the BridgeManager
// to control certain aspects of its functionality.
contract ManagerConstants {
    // STATUS constants represent the binary encoded states validators can gain
    uint256 internal constant STATUS_NEW = 0;
    uint256 internal constant STATUS_SYNCED = 1;
    uint256 internal constant STATUS_WITHDRAWN = 1 << 1;
    uint256 internal constant STATUS_OFFLINE = 1 << 3;
    uint256 internal constant STATUS_KICKED = 1 << 4;
    uint256 internal constant STATUS_ERROR = 1 << 7;

    // MASK_JAILED is used to recognize if a validator is in jail
    uint256 internal constant MASK_JAILED = STATUS_ERROR;
}
