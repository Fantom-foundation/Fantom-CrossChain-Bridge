pragma solidity ^0.6.0;

// ManagerConstants implements constants used in the BridgeManager
// to control certain aspects of its functionality.
contract ManagerConstants {
    // STATUS constants represent the binary encoded states validators can gain
    uint256 internal constant STATUS_CREATED = 1;
    uint256 internal constant STATUS_SYNCED = 1 << 1;
    uint256 internal constant STATUS_WITHDRAWN = 1 << 2;
    uint256 internal constant STATUS_OFFLINE = 1 << 3;
    uint256 internal constant STATUS_ERROR = 1 << 4;

    // MASK_INACTIVE is used to recognize if a validator is active
    uint256 internal constant MASK_INACTIVE = STATUS_WITHDRAWN | STATUS_OFFLINE | STATUS_ERROR;

    // minStakeAmount returns minimal amount of stake tokens expected to be staked
    // by a new validator to be accepted.
    function minStakeAmount() public pure returns (uint256) {
        // 3.175.000,00 sFTM
        return 3175000 * 1e18;
    }

    // maxDelegatedRatio returns the maximal ratio between the amount of tokens staked
    // by a validator himself and the amount of tokens delegated to the validator
    // from 3rd party delegates.
    function maxDelegatedRatio() public pure returns (uint256) {
        // 0% = delegation disabled
        return 0;
    }

    // unstakePeriodTime returns the number of seconds between an unstake request
    // and the actual stake unlock time.
    // If a staker requests to withdraw, the withdraw amount is placed into a request
    // and after the unstakePeriodTime() seconds pass, they can ask the contract
    // to send them the withdrawn amount.
    function unstakePeriodTime() public pure returns (uint256) {
        // 7 days
        return 60 * 60 * 24 * 7;
    }

    // rewardRatePerStakeToken returns the number of reward tokens rewarded for stake
    // per second.
    function rewardRatePerStakeToken() public pure returns (uint256) {
        // 25k tokens per day rounded; we don't really need to care about dust here
        return (25000 * 1e18) / (60 * 60 * 24);
    }
}
