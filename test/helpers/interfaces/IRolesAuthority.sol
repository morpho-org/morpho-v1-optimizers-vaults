// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IRolesAuthority {
    function setUserRole(
        address user,
        uint8 role,
        bool enabled
    ) external;
}
