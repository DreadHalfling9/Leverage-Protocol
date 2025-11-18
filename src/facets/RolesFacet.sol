// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/LibRoles.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract RolesFacet {
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(LibRoles.hasRole(role, msg.sender), "AccessControl: missing role");
        _;
    }

    /// @notice Grant `role` to `account`
    function grantRole(bytes32 role, address account) external {
        require(account != address(0), "AccessControl: account is the zero address");
        require(role != bytes32(0), "AccessControl: role is the zero hash");
        LibDiamond.enforceIsContractOwner();
        _grantRole(role, account);
    }

    /// @notice Revoke `role` from `account`
    function revokeRole(bytes32 role, address account) external {
        require(account != address(0), "AccessControl: account is the zero address");
        require(role != bytes32(0), "AccessControl: role is the zero hash");

        require(LibRoles.hasRole(LibRoles.ADMIN_ROLE, msg.sender), "AccessControl: must have admin role to revoke");

        if (role == LibRoles.ADMIN_ROLE) {
            LibDiamond.enforceIsContractOwner();
        } else {
            if (LibRoles.hasRole(LibRoles.ADMIN_ROLE, account)) {
                revert("AccessControl: admins cannot revoke other admins");
            }
        }

        _revokeRole(role, account);
    }

    /// @notice Check if `account` has `role`
    function hasRole(bytes32 role, address account) public view returns (bool) {
        LibRoles.RolesStorage storage rs = LibRoles.rolesStorage();
        return rs.roles[role].members[account];
    }

    /// @dev Internal: grant role
    function _grantRole(bytes32 role, address account) internal {
        LibRoles.RolesStorage storage rs = LibRoles.rolesStorage();
        if (!rs.roles[role].members[account]) {
            rs.roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    /// @dev Internal: revoke role
    function _revokeRole(bytes32 role, address account) internal {
        LibRoles.RolesStorage storage rs = LibRoles.rolesStorage();
        if (rs.roles[role].members[account]) {
            rs.roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }
}
