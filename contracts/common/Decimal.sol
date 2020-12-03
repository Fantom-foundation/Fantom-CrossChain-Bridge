pragma solidity ^0.6.0;

// Decimal implements a tooling for dealing with fixed point precision
// of specified amount of decimal places.
contract Decimal {
    // unit returns the coefficient for set number of decimal places
    // we use to convert floating point math to integer math
    // with reasonable precision and no real numbers rounding issues.
    // I.e.: for unit() = 1e5 we get 0.123 => 12300
    function unit() internal pure returns (uint256) {
        return 1e18;
    }
}
