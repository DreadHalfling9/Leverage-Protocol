// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

bytes32 constant SPOT_STORAGE_POSITION = keccak256("diamond.standard.spot.storage");
bytes32 constant ORDER_STORAGE_POSITION = keccak256("diamond.standard.order.storage");

library LibSpot {
    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct SpotStorage {
        mapping(address => address[]) swapPaths;
        mapping(address => int256) netExposure;
        mapping(address => uint8) maxLeverage;
        mapping(address => mapping(address => Position)) positions;
        uint16 LiquidationMargin;
        address router;
    }

    struct OrderStorage {
        mapping(uint256 => Order) orders;
        uint256 nextOrderId;
    }

    struct Position {
        address asset;
        uint256 size;
        bool isLong;
        uint256 margin;
        uint256 entryPrice;
        uint256 leverage;
    }

    struct Order {
        address user;
        address asset;
        bool isLong;
        uint256 size;
        uint256 triggerPrice;
        uint256 priceLimit;
        uint256 maxSlippage;
        uint256 collateral;
        bool isActive;
        bool reduceOnly;
        uint256 timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                             STORAGE GETTERS
    //////////////////////////////////////////////////////////////*/

    function spotStorage() internal pure returns (SpotStorage storage s) {
        bytes32 position = SPOT_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function orderStorage() internal pure returns (OrderStorage storage os) {
        bytes32 position = ORDER_STORAGE_POSITION;
        assembly {
            os.slot := position
        }
    }

    /*//////////////////////////////////////////////////////////////
                          ORDER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createOrder(
        address asset,
        bool isLong,
        uint256 size,
        uint256 triggerPrice,
        uint256 priceLimit,
        uint256 maxSlippage,
        uint256 collateral,
        bool isActive,
        bool reduceOnly,
        uint256 timestamp
    ) internal returns (uint256) {
        OrderStorage storage os = orderStorage();

        uint256 orderId = os.nextOrderId; // assign current ID
        os.nextOrderId++; // increment for next order

        os.orders[orderId] = Order({
            user: msg.sender,
            asset: asset,
            isLong: isLong,
            size: size,
            triggerPrice: triggerPrice,
            priceLimit: priceLimit,
            maxSlippage: maxSlippage,
            collateral: collateral,
            isActive: isActive,
            reduceOnly: reduceOnly,
            timestamp: timestamp
        });

        return orderId; // return the new order ID
    }

    function getOrder(uint256 orderId) internal view returns (Order memory) {
        return orderStorage().orders[orderId];
    }

    /*//////////////////////////////////////////////////////////////
                          CONFIG FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setRouter(address _router) internal {
        spotStorage().router = _router;
    }

    function setLiquidationMargin(uint16 _margin) internal {
        spotStorage().LiquidationMargin = _margin;
    }

    function setMaxLeverage(address asset, uint8 _maxLeverage) internal {
        spotStorage().maxLeverage[asset] = _maxLeverage;
    }

    function setSwapPath(address asset, address[] memory path) internal {
        SpotStorage storage s = spotStorage();
        s.swapPaths[asset] = path;
    }

    /*//////////////////////////////////////////////////////////////
                          GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRouter() internal view returns (address) {
        return spotStorage().router;
    }

    function getLiquidationMargin() internal view returns (uint16) {
        return spotStorage().LiquidationMargin;
    }

    function getMaxLeverage(address asset) internal view returns (uint8) {
        return spotStorage().maxLeverage[asset];
    }

    function getPositionSize(address user, address asset) internal view returns (uint256) {
        SpotStorage storage s = spotStorage();
        return s.positions[user][asset].size;
    }

    function getPosition(address user, address token) internal view returns (Position memory pos) {
        pos = spotStorage().positions[user][token];
    }

    function getPath(address asset) internal view returns (address[] memory) {
        SpotStorage storage s = spotStorage();
        return s.swapPaths[asset];
    }
}
