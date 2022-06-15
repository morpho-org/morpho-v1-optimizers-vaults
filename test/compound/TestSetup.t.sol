// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import {TestSetup as TestSetupCompound} from "@morpho-contracts/test-foundry/compound/setup/TestSetup.sol";
import "@forge-std/console2.sol";

contract TestSetup is TestSetupCompound {
    // TODO

    function testExample() public view {
        console2.log(dai);
    }
}
