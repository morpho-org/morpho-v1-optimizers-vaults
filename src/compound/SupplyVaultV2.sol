// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.13;

import {IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SupplyVault} from "./SupplyVault.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault V2 implementation for Morpho-Compound, which tracks rewards from Compound's pool accrued by its users.
contract SupplyVaultV2 is SupplyVault, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// STORAGE ///

    bool public upgradedToV2;

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    uint256[49] private __gap;

    /// UPGRADE ///

    /// @dev Initializes the OwnableUpgradeable contract.
    function initialize() external {
        require(!upgradedToV2, "already upgraded to V2");

        upgradedToV2 = true;
        _transferOwnership(_msgSender());
    }

    /// EXTERNAL ///

    function transferTokens(
        address _asset,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        IERC20Upgradeable(_asset).safeTransfer(_to, _amount);
    }
}
