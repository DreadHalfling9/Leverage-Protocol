// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library LibOrderBook {
    bytes32 internal constant STORAGE_POSITION = keccak256("diamond.standard.orderbook.storage");

    struct Order {
        address user;
        address asset;
        bool isLong;
        uint256 size; // Position size in asset units
        uint256 triggerPrice; // Price to activate order (0 for market orders)
        uint256 priceLimit; // Max/min execution price limit (0 if no limit)
        uint256 maxSlippage; // Slippage tolerance for execution
        uint256 collateral; // Margin posted
        bool isActive; // Whether the order is still valid\
        bool reduceOnly; // If true, this order can only reduce position size
        uint256 timestamp; // When it was placed
    }

    struct Position {
        address user;
        address asset;
        bool isLong;
        uint256 size; // Total open size in asset units
        uint256 entryPrice; // Average entry price
        uint256 collateral; // Current margin backing this position
        uint256 timestamp; // When the position was opened
    }

    struct OrderBookStorage {
        mapping(uint256 => Order) orders;
        uint256 nextOrderId;
        uint256 netExposure;
    }

    function orderBookStorage() internal pure returns (OrderBookStorage storage os) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            os.slot := position
        }
    }
}
