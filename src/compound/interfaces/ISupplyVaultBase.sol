// SPDX-License-Identifier: GNU AGPLv3
pragma solidity >=0.5.0;

import {IERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import {IMorpho} from "@contracts/compound/interfaces/IMorpho.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

interface ISupplyVaultBase is IERC4626Upgradeable {
    function morpho() external view returns (IMorpho);

    function wEth() external view returns (address);

    function comp() external view returns (ERC20);

    function poolToken() external view returns (address);

    function setRewardsRecipient(address _recipient) external;

    function transferRewards() external;
}
