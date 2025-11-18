// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/LibRoles.sol";
import "../libraries/LibOracle.sol";
import "../libraries/LibFactory.sol";
import "../libraries/LibSpot.sol";

contract OracleFacet {
    event PriceUpdated(address indexed token, uint256 price, address indexed updater);

    modifier onlyRole(bytes32 role) {
        require(LibRoles.hasRole(role, msg.sender), "OracleFacet: Access denied");
        _;
    }

    /// @notice Set price for a token (only allowed roles)
    function setPrice(address token, uint256 price) external onlyRole(LibRoles.ORACLE_ROLE) {
        LibOracle.setPrice(token, price);
        emit PriceUpdated(token, price, msg.sender);
    }

    /// @notice Get price for a token (anyone can call)
    function getPrice(address token) external view returns (uint256, uint256) {
        return LibOracle.getPrice(token);
    }

    function setSwapPath(address asset, address[] calldata path) external {
        LibSpot.SpotStorage storage s = LibSpot.spotStorage();

        require(LibFactory.marketExists(asset), "Market not created");
        require(path.length >= 2, "Invalid path");
        require(path[path.length - 1] == asset, "Path must end with asset");

        delete s.swapPaths[asset];
        for (uint256 i = 0; i < path.length; i++) {
            s.swapPaths[asset].push(path[i]);
        }
    }

    function isPriceStale(address token, uint256 maxAge) external view returns (bool) {
        return LibOracle.isPriceStale(token, maxAge);
    }
}
