pragma solidity >=0.4.24 <0.7.0;

// Initializable implements a helper contract to support initializer functions.
// To use it, replace the constructor with a function
// that has the `initializer` modifier.
// WARNING: Unlike constructors, initializer functions must be manually
// invoked. This applies both to deploying an Initializable contract, as well
// as extending an Initializable contract via inheritance.
// WARNING: When used with inheritance, manual care must be taken to not invoke
// a parent initializer twice, or ensure that all initializers are idempotent,
// because this is not dealt with automatically as with constructors.
contract Initializable {

    // initialized indicates that the contract has been initialized
    // We track it to prevent unintentional re-initialization.
    bool private initialized;

    // initializing indicates that the contract
    // is in the process of being initialized.
    bool private initializing;

    // notInitialized is used to wrap a function which is supposed
    // to run on un-initialized contracts.
    modifier notInitialized() {
        // prevent access on initialized contract
        require(initializing || isConstructor() || !initialized, "Initializable: access rejected");

        _;
    }

    // initializer modifier wraps the initializer function of a contract
    modifier initializer() {
        // prevent re-initializing of the contract
        require(initializing || isConstructor() || !initialized, "Initializable: already initialized");

        // prevent early initializer lock release
        bool isTopLevelCall = !initializing;
        if (isTopLevelCall) {
            initializing = true;
            initialized = true;
        }

        _;

        // release initializer lock
        if (isTopLevelCall) {
            initializing = false;
        }
    }

    // isConstructor returns true if and only if the function is running in the constructor
    function isConstructor() private view returns (bool) {
        // extcodesize checks the size of the code stored in an address, and
        // address returns the current address. Since the code is still not
        // deployed when running a constructor, any checks on its code size will
        // yield zero, making it an effective way to detect if a contract is
        // under construction or not.
        address self = address(this);
        uint256 cs;
        assembly {cs := extcodesize(self)}
        return cs == 0;
    }

    // Reserved storage space to allow for layout changes in the future.
    uint256[50] private ______gap;
}