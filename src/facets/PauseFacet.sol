// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibPause} from "../libraries/LibPause.sol";
import "../libraries/LibRoles.sol";

contract PauseFacet {
    event Paused(address indexed account);
    event Unpaused(address indexed account);

    modifier onlyRole(bytes32 role) {
        require(LibRoles.hasRole(role, msg.sender), "PauseFacet: Access denied");
        _;
    }

    /// @notice Pause the contract
    function pause() external onlyRole(LibRoles.ADMIN_ROLE) {
        LibPause.setPaused(true);
        emit Paused(msg.sender);
    }

    /// @notice Unpause the contract (only owner)
    function unpause() external {
        LibDiamond.enforceIsContractOwner();
        LibPause.setPaused(false);
        emit Unpaused(msg.sender);
    }

    /// @notice Returns true if contract is paused
    function paused() external view returns (bool) {
        return LibPause.isPaused();
    }
}
