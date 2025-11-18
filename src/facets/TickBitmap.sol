// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract TickBitmap {
    // Mapping from word position to 256-bit bitmap
    mapping(int16 => uint256) public tickBitmap;

    // Set tick as initialized
    function setTick(int24 tick) external {
        (int16 wordPos, uint8 bitPos) = getPosition(tick);
        tickBitmap[wordPos] |= (1 << bitPos);
    }

    // Clear tick (no orders)
    function clearTick(int24 tick) external {
        (int16 wordPos, uint8 bitPos) = getPosition(tick);
        tickBitmap[wordPos] &= ~(1 << bitPos);
    }

    // Check if tick is initialized
    function isTickInitialized(int24 tick) public view returns (bool) {
        (int16 wordPos, uint8 bitPos) = getPosition(tick);
        return (tickBitmap[wordPos] & (1 << bitPos)) != 0;
    }

    // Get word and bit positions for tick
    function getPosition(int24 tick) internal pure returns (int16 wordPos, uint8 bitPos) {
        // Ticks are grouped in 256 ticks per word
        wordPos = int16(tick >> 8); // tick / 256
        bitPos = uint8(uint24(tick) % 256); // tick % 256
    }
}
