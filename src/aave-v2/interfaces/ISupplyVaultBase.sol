// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import {IERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import {IMorpho} from "@contracts/aave-v2/interfaces/IMorpho.sol";

interface ISupplyVaultBase is IERC4626Upgradeable {
    function morpho() external view returns (IMorpho);

    function poolToken() external view returns (address);

    function transferRewards() external;
}
