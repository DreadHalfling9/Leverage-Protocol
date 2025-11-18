// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract OrderBook {
    struct Order {
        address user;
        uint256 amount;
        uint256 filled;
    }

    // Use int24 for tick keys (can be negative like Uniswap)
    mapping(int24 => Order[]) public bids;
    mapping(int24 => Order[]) public asks;
    mapping(int24 => uint256) public bidPointers;
    mapping(int24 => uint256) public askPointers;

    int24[] public tickList; // track active ticks
    uint256 public tickPointer; // index in tickList
    uint256 public orderPointer; // index within orders at current tick

    uint256 public constant BATCH_SIZE = 5;

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function placeOrder(bool isBuy, int24 tick, uint256 amount) external {
        require(amount > 0, "Amount must be > 0");

        Order memory newOrder = Order({user: msg.sender, amount: amount, filled: 0});

        // Use correct mapping
        if (isBuy) {
            if (bidPointers[tick] == bids[tick].length) {
                delete bids[tick];
                bidPointers[tick] = 0;
            }
            bids[tick].push(newOrder);
        } else {
            if (askPointers[tick] == asks[tick].length) {
                delete asks[tick];
                askPointers[tick] = 0;
            }
            asks[tick].push(newOrder);
        }

        // Add to tickList if this is a new tick (naive implementation — duplicates possible)
        tickList.push(tick);
    }

    function matchOrders(uint256 maxLoops) external {
        uint256 loops = 0;

        while (loops < maxLoops && tickPointer < tickList.length) {
            int24 currentTick = tickList[tickPointer];
            Order[] storage buyOrders = bids[currentTick];
            Order[] storage sellOrders = asks[currentTick];

            while (loops < maxLoops && orderPointer < buyOrders.length && orderPointer < sellOrders.length) {
                Order storage buy = buyOrders[orderPointer];
                Order storage sell = sellOrders[orderPointer];

                uint256 matchAmount = min(buy.amount - buy.filled, sell.amount - sell.filled);

                buy.filled += matchAmount;
                sell.filled += matchAmount;

                // Emit events or handle token transfers here

                // Move pointer if both orders are filled
                if (buy.filled == buy.amount && sell.filled == sell.amount) {
                    orderPointer++;
                }

                loops++;
            }

            if (orderPointer >= buyOrders.length || orderPointer >= sellOrders.length) {
                orderPointer = 0;
                tickPointer++;
            }
        }

        if (tickPointer >= tickList.length) {
            tickPointer = 0;
        }
    }
}
