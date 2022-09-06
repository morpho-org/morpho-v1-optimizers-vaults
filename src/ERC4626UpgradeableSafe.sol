// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import {ERC4626Upgradeable, ERC20Upgradeable, IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

/// @title ERC4626UpgradeableSafe.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626 Tokenized Vault abstract upgradeable implementation tweaking OZ's implementation to make it safer at initialization.
abstract contract ERC4626UpgradeableSafe is ERC4626Upgradeable {
    /// CONSTRUCTOR ///

    /// @notice Constructs the contract.
    /// @dev The contract is automatically marked as initialized when deployed so that nobody can highjack the implementation contract.
    constructor() initializer {}

    /// UPGRADE ///

    function __ERC4626UpgradeableSafe_init(
        IERC20MetadataUpgradeable _asset,
        uint256 _initialDeposit
    ) internal {
        __ERC4626_init(_asset);
        __ERC4626UpgradeableSafe_init_unchained(_initialDeposit);
    }

    function __ERC4626UpgradeableSafe_init_unchained(uint256 _initialDeposit) internal {
        // Sacrifice an initial seed of shares to ensure a healthy amount of precision in minting shares.
        // Set to 0 at your own risk.
        // Caller must have approved the asset to this contract's address.
        // See: https://github.com/Rari-Capital/solmate/issues/178
        if (_initialDeposit > 0) deposit(_initialDeposit, address(this));
    }

    /// EXTERNAL ///

    /// @notice Deposits a given amount of underlying asset into the vault.
    /// @param assets The amount of underlying asset to deposit. The caller must have approved this contract to spend this amount.
    /// @return The amount of shares minted.
    function deposit(uint256 assets) external returns (uint256) {
        return deposit(assets, msg.sender);
    }

    /// @notice Mints a given amount of shares from the vault.
    /// @param shares The amount of shares to mint. The caller must have approved this contract to spend the corresponding amount of underlying asset.
    /// @return The amount of assets deposited.
    function mint(uint256 shares) external returns (uint256) {
        return deposit(shares, msg.sender);
    }

    /// @notice Withdraws a given amount of underlying asset from the vault.
    /// @param assets The amount of underlying asset to withdraw.
    /// @return The amount of shares withdrawn.
    function withdraw(uint256 assets) external returns (uint256) {
        return withdraw(assets, msg.sender, msg.sender);
    }

    /// @notice Withdraws a given amount of underlying asset from the vault and send them to `receiver`.
    /// @param assets The amount of underlying asset to withdraw.
    /// @param receiver The address of the receiver of the funds.
    /// @return The amount of shares withdrawn.
    function withdraw(uint256 assets, address receiver) public returns (uint256) {
        return withdraw(assets, receiver, msg.sender);
    }

    /// @notice Redeems a given amount of shares from the vault.
    /// @param shares The amount of shares to redeem.
    /// @return The amount of assets withdrawn.
    function redeem(uint256 shares) external returns (uint256) {
        return redeem(shares, msg.sender, msg.sender);
    }

    /// @notice Redeems a given amount of shares from the vault and send them to `receiver`.
    /// @param shares The amount of shares to redeem.
    /// @param receiver The address of the receiver of the funds.
    /// @return The amount of assets withdrawn.
    function redeem(uint256 shares, address receiver) public returns (uint256) {
        return redeem(shares, receiver, msg.sender);
    }
}
