// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import {ISupplyVault} from "./interfaces/ISupplyVault.sol";

import {SupplyVaultBase} from "./SupplyVaultBase.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Aave V2.
contract SupplyVault is ISupplyVault, SupplyVaultBase {
    /// CONSTRUCTOR ///

    /// @dev Initializes network-wide immutables.
    /// @param _morpho The address of the main Morpho contract.
    /// @param _morphoToken The address of the Morpho Token.
    /// @param _lens The address of the Morpho Lens.
    /// @param _recipient The recipient of the rewards that will redistribute them to vault's users.
    constructor(
        address _morpho,
        address _morphoToken,
        address _lens,
        address _recipient
    ) SupplyVaultBase(_morpho, _morphoToken, _lens, _recipient) {}

    /// INITIALIZER ///

    /// @dev Initializes the vault.
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    function initialize(
        address _poolToken,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit
    ) external initializer {
        __SupplyVaultBase_init(_poolToken, _name, _symbol, _initialDeposit);
    }
}
