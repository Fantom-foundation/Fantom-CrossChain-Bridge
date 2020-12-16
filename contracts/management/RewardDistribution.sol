pragma solidity ^0.6.0;

import "../common/IERC20.sol";
import "../common/SafeMath.sol";
import "../common/SafeERC20.sol";
import "../common/Context.sol";

// RewardDistribution is an abstract contract
// responsible for stake rewards distribution.
contract RewardDistribution is Context {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // rewardToken represents the address of an ERC20 token used for staking
    // rewards on the Bridge.
    IERC20 public rewardToken;

    // rewardsStash represents a container where calculated rewards are stored before
    // the owner asks for the refund.
    // Map: Staker => ValidatorID => stashed amount
    mapping(address => mapping(uint256 => uint256)) public getRewardStash;

    // rewardPerTokenPaid represents a value of the rewardPerTokenLast already consumed
    // by the reward update function to calculate current rewards per stake.
    // Map: Staker => ValidatorID => rewardPerTokenLast amount consumed
    mapping(address => mapping(uint256 => uint256)) rewardPerTokenPaid;

    // rewardRate represents the rate of reward tokens distribution.
    // It stores the amount of total reward tokens distributed per second
    // to the total stake amount.
    uint256 public rewardRate;

    // rewardPerTokenLast represents the latest calculated total amount of reward
    // per a stake token.
    uint256 public rewardPerTokenLast;

    // rewardPerTokenUpdated represents the timestamp
    // of the latest rewards per stake token update.
    uint256 public rewardPerTokenUpdated;

    // rewardPerTokenDecimalsCorrection represents a decimal correction
    // used by reward distribution for more precise fractions handling.
    uint256 rewardPerTokenDecimalsCorrection = 1e18;

    // -------------------------------------------------
    // events
    // -------------------------------------------------

    // RewardRateChanged event is emitted when a new reward rate value is set.
    event RewardRateChanged(uint256 oldRate, uint256 newRate);

    // RewardPaid event is emitted when an account claims their rewards from the system.
    event RewardPaid(address indexed staker, uint256 indexed toValidatorID, uint256 amount);

    // -------------------------------------------------
    // interface
    // -------------------------------------------------

    // rewardClaim allows caller to claim their rewards for the stake towards given
    // Validator identified by its ID, both stashed and pending.
    function rewardClaim(uint256 validatorID) external {
        // who is the staker we are working with
        address staker = _sender();

        // update the rewards first so we stash any pending rewards
        rewardUpdate(staker, validatorID);

        // make sure there is a reward and that it can be claimed
        require(0 != getRewardsStash[staker][validatorID], "RewardDistribution: no reward earned");
        require(canClaimRewards(staker, validatorID), "RewardDistribution: claim rejected");
        require(getRewardsStash[staker][validatorID] <= rewardToken.balanceOf(address(this)), "RewardDistribution: reward not available");

        // get the current amount
        uint256 amount = getRewardsStash[staker][validatorID];

        // reset the stored value so any re-entrance would not find any remaining reward
        getRewardsStash[staker][validatorID] = 0;

        // send the tokens
        rewardToken.safeTransfer(staker, amount);

        // emit notification
        emit RewardPaid(staker, validatorID, amount);
    }

    // rewardUpdateGlobal updates the global stored reward distribution state for all stakes.
    function rewardUpdateGlobal() public {
        rewardPerTokenLast = rewardPerToken();
        rewardPerTokenUpdated = _now();
    }

    // rewardUpdate updates the reward distribution state and the accumulated reward
    // for the given stake; it is called on each stake token amount change to reflect
    // the impact on reward distribution.
    function rewardUpdate(address staker, uint256 toValidatorID) public {
        // calculate the current reward per token value globally
        rewardUpdateGlobal();

        // stash all the current pending reward, if any
        getRewardsStash[staker][toValidatorID] = rewardPending(staker, toValidatorID);

        // adjust paid part of the accumulated reward
        // if the account is not eligible to receive reward up to this point
        // we just skip it and they will never get it
        getRewardsUpdated[staker][toValidatorID] = rewardLastPerToken;
    }

    // rewardPending calculates the amount of pending reward for the given stake
    // including the current stash balance.
    function rewardPending(address staker, uint256 toValidatorID) public view returns (uint256) {
        // calculate earned rewards based on the amount of staked tokens
        return getStakeBy(staker, toValidatorID)
        /* multiply by the unpaid reward per token */
        .mul(rewardPerToken().sub(rewardPerTokenPaid[staker][toValidatorID]))
        /* remove the decimal precision adjustment of the rewardPerToken() call */
        .div(rewardPerTokenDecimalsCorrection)
        /* add existing stash */
        .add(getRewardStash[staker][toValidatorID]);
    }

    // rewardPerToken calculates the reward share per single stake token.
    // It's calculated from the amount of tokens rewarded per second
    // and the total amount of staked tokens.
    // Note: the value is not in WEI tokens, it's adjusted to increase precision
    // using the rewardPerTokenDecimalsCorrection decimal places.
    function rewardPerToken() public view returns (uint256) {
        // how many tokens are staked? check for total to avoid div by zero later
        uint256 total = getStakeTotal();
        if (0 == total) {
            return rewardPerTokenLast;
        }

        // return current accumulated rewards per stake token
        return rewardPerToken.add(
        /* number of seconds passed from the last update */
            _now().sub(rewardPerTokenUpdated)
            /* times the rate per second */
            .mul(rewardRate)
            /* times the decimal correction */
            .mul(rewardPerTokenDecimalsCorrection)
            /* div/per total staked amount */
            .div(total)
        );
    }

    // canClaimRewards checks if a reward for the stake can be claimed.
    function canClaimRewards(address staker, uint256 validatorID) public view returns (bool) {
        return !isStakeJailed(staker, validatorID);
    }

    // setRewardRate changes the base reward rate value.
    function setRewardRate(uint256 newValue) external {
        // emit an event about the update and change the value
        emit RewardRateChanged(baseRewardRate, newValue);
        rewardRate = newValue;
    }

    // -------------------------------------------------
    // internal functions
    // -------------------------------------------------
    function _initRewards(address token, uint256 rate) internal {
        rewardToken = IERC20(rwToken);
        rewardRate = rate;
        rewardPerTokenUpdated = _now();
    }

    // getTotalStake returns the total amount of staked tokens for the reward
    // distribution calculation.
    function getStakeTotal() internal returns (uint256);

    // getStakeBy returns the amount of staked tokens of a specific staker/validator combo
    // for the reward distribution calculation.
    function getStakeBy(address staker, uint256 validatorID) internal returns (uint256);

    // isStakeJailed returns jail status of the given stake.
    function isStakeJailed(address staker, uint256 validatorID) public view returns (bool);
}
