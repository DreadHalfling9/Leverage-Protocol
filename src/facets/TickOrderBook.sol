// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Basis Point Tick Order Book
/// @notice Tick spacing = 1 (1 bp = 0.01%) increments

contract BPTickOrderBook {
    struct Order {
        address user;
        uint256 amount; // remaining amount
        uint256 filled; // filled amount
    }

    struct Tick {
        Order[] orders;
        uint256 nextIndex; // FIFO pointer
    }

    // Orders mapped by tick index
    mapping(int24 => Tick) public longTicks;
    mapping(int24 => Tick) public shortTicks;

    int24 public bestLongTick; // highest bid
    int24 public bestShortTick; // lowest ask

    // --------------------------
    // Price <-> Tick conversions
    // --------------------------
    // Price per tick = 1.0001^tick
    // Tick spacing = 1 → 1 bp increments

    function tickToPrice(int24 tick) public pure returns (uint256) {
        // Using Q64.96 style fixed-point
        // 1.0001^tick
        uint256 result = 1e18; // assume 18 decimals
        uint256 base = 1000100000000000000; // 1.0001 in 1e18 fixed point
        int256 tickSigned = int256(tick);

        uint256 absTick = tickSigned < 0 ? uint256(-tickSigned) : uint256(tickSigned);
        while (absTick > 0) {
            if (absTick % 2 == 1) {
                result = (result * base) / 1e18;
            }
            base = (base * base) / 1e18;
            absTick /= 2;
        }

        if (tick < 0) {
            result = 1e36 / result; // invert for negative ticks
        }
        return result; // price in 1e18 precision
    }

    function priceToTick(uint256 price) public pure returns (int24) {
        require(price > 0, "Price must be > 0");

        // Convert price to Q128.128 for precision
        uint256 ratio = price << 128;

        // Compute log2(ratio) using iterative approximation
        uint256 msb = mostSignificantBit(ratio);
        int256 log2 = (int256(msb) - 128) << 64;

        // Refine log2 with series multiplications (similar to Uniswap)
        // log_1.0001(price) = log2(price) / log2(1.0001)
        int24 tick = int24(log2 / 0xB17217F7D1CF79AC); // 0xB172... is Q64.64 ln(1.0001) in fixed-point

        return tick;
    }

    // Helper: find most significant bit
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        require(x > 0);
        if (x >= 2 ** 128) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 2 ** 64) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 2 ** 32) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 2 ** 16) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 2 ** 8) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 2 ** 4) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 2 ** 2) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 2 ** 1 /* x >>= 1; */ ) msb += 1;
    }

    // --------------------------
    // Place limit order
    // --------------------------
    function placeLimitOrder(bool isLong, int24 tick, uint256 amount) external {
        uint256 remaining = amount;

        // Auto-fill if crossed
        if (isLong && bestShortTick != 0 && tick >= bestShortTick) {
            remaining = _fillOrder(true, tick, remaining);
        } else if (!isLong && bestLongTick != 0 && tick <= bestLongTick) {
            remaining = _fillOrder(false, tick, remaining);
        }

        // Add remaining to book
        if (remaining > 0) {
            Tick storage t = isLong ? longTicks[tick] : shortTicks[tick];
            t.orders.push(Order(msg.sender, remaining, 0));

            // Update best tick
            if (isLong) {
                if (tick > bestLongTick) bestLongTick = tick;
            } else {
                if (bestShortTick == 0 || tick < bestShortTick) bestShortTick = tick;
            }
        }
    }

    // --------------------------
    // Market fill
    // --------------------------
    function _fillOrder(bool isMarketLong, int24 startTick, uint256 amount) internal returns (uint256) {
        uint256 remaining = amount;

        if (isMarketLong) {
            int24 tick = bestShortTick;
            while (remaining > 0 && tick <= startTick) {
                Tick storage t = shortTicks[tick];
                while (t.nextIndex < t.orders.length && remaining > 0) {
                    Order storage order = t.orders[t.nextIndex];
                    uint256 fillAmount = order.amount > remaining ? remaining : order.amount;

                    order.amount -= fillAmount;
                    order.filled += fillAmount;
                    remaining -= fillAmount;

                    if (order.amount == 0) t.nextIndex += 1;

                    // TODO: handle balances / transfers
                }
                tick += 1;
                if (shortTicks[tick].orders.length == 0) break;
            }
        } else {
            int24 tick = bestLongTick;
            while (remaining > 0 && tick >= startTick) {
                Tick storage t = longTicks[tick];
                while (t.nextIndex < t.orders.length && remaining > 0) {
                    Order storage order = t.orders[t.nextIndex];
                    uint256 fillAmount = order.amount > remaining ? remaining : order.amount;

                    order.amount -= fillAmount;
                    order.filled += fillAmount;
                    remaining -= fillAmount;

                    if (order.amount == 0) t.nextIndex += 1;

                    // TODO: handle balances / transfers
                }
                if (tick == type(int24).min) break;
                tick -= 1;
            }
        }

        return remaining;
    }

    // --------------------------
    // View top order at a tick
    // --------------------------
    function getTopOrder(bool isLong, int24 tick) external view returns (Order memory) {
        Tick storage t = isLong ? longTicks[tick] : shortTicks[tick];
        if (t.nextIndex < t.orders.length) {
            return t.orders[t.nextIndex];
        }
        return Order(address(0), 0, 0);
    }
}
