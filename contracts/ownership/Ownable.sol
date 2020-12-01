pragma solidity ^0.5.0;

import "../common/Initializable.sol";

// Ownable implements basic access control mechanism with a single account,
// the owner, that has been granted an elevated access privilege to specific
// functions of the inherited contract.
contract Ownable is Initializable {
    // keep the owner address
    address private _owner;

    // OwnershipTransferred informs about ownership changes
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // initialize sets the initial state of the contract
    // by assigning the first owner address
    function initialize(address sender) internal initializer {
        _owner = sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    // owner exposes the current owner address
    function owner() public view returns (address) {
        return _owner;
    }

    // isOwner checks if the given address is the current owner
    function isOwner(address adr) public view returns (bool) {
        return adr == _owner;
    }

    // onlyOwner allows to wrap functions to check for elevated privileges
    // before they are executed.
    modifier onlyOwner() {
        // check for privileges
        require(isOwner(msg.sender), "Ownable: access restricted");
        _;
    }

    // renounceOwnership drops the ownership leaving the contract without
    // an owner. Please note, this can not be restored and any functionality
    // originally accessible only to the owner will be inaccessible.
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    // transferOwnership transfers ownership of the contract from the current
    // owner to a newly specified address. The old owner looses access
    // to all the functions with controlled access.
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    // _transferOwnership implements the ownership transfer with all the necessary
    // checks so the transfer is safe and sane.
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: zero address not allowed");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    // Reserved storage space to allow for layout changes in the future.
    uint256[50] private ______gap;
}
