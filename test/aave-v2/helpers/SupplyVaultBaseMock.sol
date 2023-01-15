// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import {SupplyVaultBase} from "src/aave-v2/SupplyVaultBase.sol";

contract SupplyVaultBaseMock is SupplyVaultBase {
    constructor(
        address _morpho,
        address _morphoToken,
        address _lens,
        address _recipient
    ) SupplyVaultBase(_morpho, _morphoToken, _lens, _recipient) {}
}
