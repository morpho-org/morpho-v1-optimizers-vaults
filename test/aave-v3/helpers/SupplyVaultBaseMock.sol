// SPDX-License-Identifier: GNU AGPLv3
pragma solidity >=0.8.0;

import {SupplyVaultBase} from "src/aave-v3/SupplyVaultBase.sol";

contract SupplyVaultBaseMock is SupplyVaultBase {
    constructor(
        address _morpho,
        address _morphoToken,
        address _recipient
    ) SupplyVaultBase(_morpho, _morphoToken, _recipient) {}
}
