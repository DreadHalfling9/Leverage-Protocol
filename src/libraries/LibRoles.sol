// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library LibRoles {
    bytes32 constant STORAGE_POSITION = keccak256("diamond.standard.roles.storage");

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    struct RoleData {
        mapping(address => bool) members;
    }

    struct RolesStorage {
        mapping(bytes32 => RoleData) roles;
    }

    function rolesStorage() internal pure returns (RolesStorage storage rs) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            rs.slot := position
        }
    }

    function hasRole(bytes32 role, address account) internal view returns (bool) {
        RolesStorage storage rs = rolesStorage();
        return rs.roles[role].members[account];
    }

    function grantRole(bytes32 role, address account) internal {
        RolesStorage storage rs = rolesStorage();
        rs.roles[role].members[account] = true;
    }

    function revokeRole(bytes32 role, address account) internal {
        RolesStorage storage rs = rolesStorage();
        rs.roles[role].members[account] = false;
    }

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "LibRoles: Access denied");
        _;
    }
}
