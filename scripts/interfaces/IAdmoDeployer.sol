// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IAdmoDeployer {
    function performCreate2(
        uint256 value,
        bytes memory deploymentData,
        bytes32 salt
    ) external returns (address newContract);

    function performCreate(
        uint256 value,
        bytes memory deploymentData,
        bool transferOwnership
    ) external returns (address newContract);
}
