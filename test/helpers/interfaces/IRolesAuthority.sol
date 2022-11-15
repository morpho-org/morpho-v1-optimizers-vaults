// SPDX-License-Identifier: GNU AGPLv3
pragma solidity >=0.5.0;

interface IRolesAuthority {
    function setUserRole(
        address user,
        uint8 role,
        bool enabled
    ) external;
}
