// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

// Context abstract contract implements some context tooling functions.
contract Context {
    // _sender returns the address of the current trx sender
    function _sender() internal view returns (address) {
        return msg.sender;
    }

    // _now returns the current timestamp as available to the contract call
    function _now() internal view returns (uint256) {
        return block.timestamp;
    }
}
