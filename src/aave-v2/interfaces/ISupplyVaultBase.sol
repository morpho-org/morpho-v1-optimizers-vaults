// SPDX-License-Identifier: GNU AGPLv3
pragma solidity >=0.5.0;

import {IERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import {IMorpho} from "@contracts/aave-v2/interfaces/IMorpho.sol";

interface ISupplyVaultBase is IERC4626Upgradeable {
    function morpho() external view returns (IMorpho);

    function poolToken() external view returns (address);

    function setRewardsRecipient(address _recipient) external;

    function transferRewards() external;
}