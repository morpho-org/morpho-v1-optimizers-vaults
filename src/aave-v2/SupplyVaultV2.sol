// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.13;

import {ISupplyVault} from "./interfaces/ISupplyVault.sol";

import {IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SupplyVaultBase} from "./SupplyVaultBase.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Aave V2.
contract SupplyVaultV2 is ISupplyVault, SupplyVaultBase, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// STORAGE ///

    bool public upgradedToV2;

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    uint256[50] private __gap;

    /// CONSTRUCTOR ///

    /// @dev Initializes network-wide immutables.
    /// @param _morpho The address of the main Morpho contract.
    constructor(address _morpho) SupplyVaultBase(_morpho) {
        upgradedToV2 = true; // Initialize the implementation contract.
    }

    /// @dev Initializes the OwnableUpgradeable.
    function initialize() external {
        require(!upgradedToV2, "already upgraded to V2");

        upgradedToV2 = true;
        _transferOwnership(_msgSender());
    }

    function transfer(
        address _asset,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        IERC20Upgradeable(_asset).safeTransfer(_to, _amount);
    }
}
