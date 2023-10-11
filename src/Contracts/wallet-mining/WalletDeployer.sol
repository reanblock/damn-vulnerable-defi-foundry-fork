// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGnosisSafeProxyFactory {
    function createProxy(address masterCopy, bytes calldata data) external returns (address);
}

/**
 * @title  WalletDeployer
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @notice A contract that allows deployers of Gnosis Safe wallets (v1.1.1) to be rewarded.
 *         Includes an optional authorization mechanism to ensure only expected accounts
 *         are rewarded for certain deployments.
 */
contract WalletDeployer {
    // Addresses of the Gnosis Safe Factory and Master Copy v1.1.1
    IGnosisSafeProxyFactory public constant fact = IGnosisSafeProxyFactory(0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B);
    address public constant copy = 0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F;

    uint256 public constant pay = 1 ether;
    address public immutable chief = msg.sender;
    address public immutable gem;

    address public mom; // is the AuthorizerUpgradeable proxy

    error Boom();

    constructor(address _gem) {
        gem = _gem;
    }

    /**
     * @notice Allows the chief to set an authorizer contract.
     * Can only be called once. TODO: double check.
     */
    function rule(address _mom) external {
        if (msg.sender != chief || _mom == address(0) || mom != address(0)) {
            revert Boom();
        }
        mom = _mom;
    }

    /**
     * @notice Allows the caller to deploy a new Safe wallet and receive a payment in return.
     *         If the authorizer is set, the caller must be authorized to execute the deployment.
     * @param wat initialization data to be passed to the Safe wallet
     * @return aim address of the created proxy
     */
    function drop(bytes memory wat) external returns (address aim) {
        aim = fact.createProxy(copy, wat);
        if (mom != address(0) && !can(msg.sender, aim)) {
            revert Boom();
        }
        IERC20(gem).transfer(msg.sender, pay);
    }

    // Explanation of GAS code (0xth3g450pt1m1z0r)
    function can(address u, address a) public view returns (bool) {
        assembly {
            // AUthorizer Upgrader proxy address (mom)
            let m := sload(0)
            // Ensure m has code
            if iszero(extcodesize(m)) { return(0, 0) }
            // load free memory address at 0x40 into p
            let p := mload(0x40)
            // store [p + 0x44] at 0x40 to update free memory pointer
            mstore(0x40, add(p, 0x44))
            // store at p the sighash for the can() function in AuthorizeUpgrader
            mstore(p, shl(0xe0, 0x4538c4eb))
            // store at p + 0x04 the imp address
            mstore(add(p, 0x04), u)
            // store at p + 0x24 the aim address
            mstore(add(p, 0x24), a)
            // Static call the function and check return is > 0
            if iszero(staticcall(gas(), m, p, 0x44, p, 0x20)) { return(0, 0) }
            // Check return data size is NOT zero AND return data is 0 then return false 0
            if and(not(iszero(returndatasize())), iszero(mload(p))) { return(0, 0) }
        }
        return true;
    }
}
