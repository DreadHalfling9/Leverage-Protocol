// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console.sol";

import "../ERC4626Vault.sol";
import {LibFactory} from "../libraries/LibFactory.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import "../libraries/LibSpot.sol";

contract VaultFactoryFacet {
    event MarketCreated(address indexed asset, address vault);

    /// @notice Deploy a new ERC4626 vault for a given underlying asset
    /// @param asset The address of the underlying ERC20 token
    /// @param name The name of the vault token
    /// @param symbol The symbol of the vault token

    function createMarket(address asset, string memory name, string memory symbol) external {
        LibDiamond.enforceIsContractOwner();

        require(asset != address(0), "Invalid asset");
        require(!LibFactory.marketExists(asset), "Market already exists");

        // Deploy the vault
        ERC4626Vault newVault = new ERC4626Vault(IERC20(asset), name, symbol);

        // Register the market with the new vault
        LibFactory.createMarket(asset, address(newVault));

        emit MarketCreated(asset, address(newVault));
    }

    function setMaxLeverage(address asset, uint8 _maxLeverage) external {
        LibSpot.setMaxLeverage(asset, _maxLeverage);
    }

    /// @notice Get the vault address for an underlying asset
    /// @param asset The underlying ERC20 token address
    function getMarket(address asset) external view returns (address) {
        return LibFactory.getMarket(asset);
    }

    function marketExists(address asset) external view returns (bool) {
        return LibFactory.marketExists(asset);
    }

    function getMaxLeverage(address asset) external view returns (uint8) {
        return LibSpot.getMaxLeverage(asset);
    }
}

contract TickBook {
    struct Tick {
        uint256[] orders; // simple array of order IDs
        bool initialized; // tracks if tick is active
    }

    mapping(int24 => Tick) public ticks; // mapping price tick -> orders

    /// @notice Add an order to a tick
    function addOrder(int24 tickId, uint256 orderId) external {
        Tick storage t = ticks[tickId];

        // if it's the first order, mark tick as initialized
        if (!t.initialized) {
            t.initialized = true;
        }

        t.orders.push(orderId);
    }

    /// @notice Remove the last order from a tick
    function removeLastOrder(int24 tickId) external {
        Tick storage t = ticks[tickId];
        require(t.orders.length > 0, "No orders");

        // remove last order
        t.orders.pop();

        // reset tick if empty
        if (t.orders.length == 0) {
            delete ticks[tickId]; // deletes orders[] and resets initialized=false
        }
    }

    /// @notice Get number of orders at a tick
    function getOrderCount(int24 tickId) external view returns (uint256) {
        return ticks[tickId].orders.length;
    }
}
