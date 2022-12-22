// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.13;

import {SupplyVaultBase} from "src/compound/SupplyVaultBase.sol";

contract SupplyVaultBaseMock is SupplyVaultBase {
    constructor(
        address _morpho,
        address _morphoToken,
        address _lens,
        address _recipient
    ) SupplyVaultBase(_morpho, _morphoToken, _lens, _recipient) {}
}
