// SPDX-License-Identifier: GNU AGPLv3
pragma solidity >=0.8.0;

import {IERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import {IMorpho} from "@contracts/compound/interfaces/IMorpho.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

interface ISupplyVaultBase is IERC4626Upgradeable {
    function morpho() external returns (IMorpho);

    function wEth() external returns (address);

    function comp() external returns (ERC20);

    function poolToken() external returns (address);

    function transferTokens(
        address _asset,
        address _to,
        uint256 _amount
    ) external;
}
