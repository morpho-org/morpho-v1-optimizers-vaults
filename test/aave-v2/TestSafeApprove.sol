// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
// IERC20 is already imported from aave libs
import {IERC20 as IERC20OZ, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAToken} from "@contracts/aave-v2/interfaces/aave/IAToken.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

import {IAdmoDeployer} from "@vaults/interfaces/IAdmoDeployer.sol";

contract TestSafeApprove is TestSetupVaults {
    using SafeTransferLib for ERC20;
    using SafeERC20 for IERC20OZ;

    bytes constant CREATION_CODE = abi.encodePacked(uint256(0));
    bytes32 constant salt = keccak256(abi.encode(0));

    // fails
    function testSafeTransferLibApprove() public {
        address target = Create2.computeAddress(salt, keccak256(CREATION_CODE), address(0));
        vm.prank(address(supplier1));
        ERC20(crv).safeApprove(target, 1e8);
    }

    // passes
    function testSafeERC20Approve() public {
        address target = Create2.computeAddress(salt, keccak256(CREATION_CODE), address(0));
        vm.prank(address(supplier1));
        IERC20OZ(crv).safeApprove(target, 1e8);
    }
}
