// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";
import {IERC20 as IERC20OZ, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAToken} from "@contracts/aave-v2/interfaces/aave/IAToken.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

contract TestSafeApprove is TestSetupVaults {
    using SafeTransferLib for ERC20;
    using SafeERC20 for IERC20OZ;

    bytes constant CREATION_CODE = abi.encodePacked(uint256(0));
    bytes32 constant salt = keccak256(abi.encode(0));

    // Create2.computeAddress(salt, keccak256(CREATION_CODE), address(0))
    address constant TARGET = 0xE045f841eC01Ce6e81060004f1B42b05D3ce01A3;

    // fails
    // with compute address
    function testSafeTransferLibApprove1() public {
        address target = Create2.computeAddress(salt, keccak256(CREATION_CODE), address(0));
        assertEq(target, TARGET);
        vm.prank(address(supplier1));
        ERC20(crv).safeApprove(target, 1e8);
    }

    // passes
    // without compute address
    function testSafeTransferLibApprove2() public {
        vm.prank(address(supplier1));
        ERC20(crv).safeApprove(TARGET, 1e8);
    }

    // passes
    // another token
    function testSafeTransferLibApprove3() public {
        address target = Create2.computeAddress(salt, keccak256(CREATION_CODE), address(0));
        assertEq(target, TARGET);
        vm.prank(address(supplier1));
        ERC20(dai).safeApprove(target, 1e8);
    }

    // passes
    // with compute address
    function testSafeTransferLibApprove4() public {
        address target = Create2.computeAddress(salt, keccak256(CREATION_CODE), address(0));
        assertEq(target, TARGET);
        vm.prank(address(supplier1));
        ERC20(crv).safeApprove(TARGET, 1e8);
    }

    // passes
    // with SafeERC20
    function testSafeERC20Approve() public {
        address target = Create2.computeAddress(salt, keccak256(CREATION_CODE), address(0));
        assertEq(target, TARGET);
        vm.prank(address(supplier1));
        IERC20OZ(crv).safeApprove(target, 1e8);
    }
}
