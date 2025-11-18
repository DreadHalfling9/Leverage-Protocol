// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract TickMappingArrayTest {
    struct Tick {
        uint256 liquidity;
        address user;
    }

    // mapping from tick index to an array of Tick structs
    mapping(int24 => Tick[]) public ticks;

    // track tick keys so we can iterate for logging
    int24[] public tickKeys;

    function testTickMappingArray() public {
        // Add some ticks
        ticks[100].push(Tick(500, address(0x123)));
        ticks[-50].push(Tick(300, address(0x456)));
        ticks[100].push(Tick(200, address(0x789))); // multiple entries at same tick
        ticks[-50].push(Tick(100, address(0xabc)));
        ticks[200].push(Tick(400, address(0xdef))); // another tick

        // track which tick indices have entries
        tickKeys.push(100);
        tickKeys.push(-50);

        // Log all ticks
        console.log("Before deletion:");
        for (uint256 k = 0; k < tickKeys.length; k++) {
            int24 tickIndex = tickKeys[k];
            Tick[] storage arr = ticks[tickIndex];
            for (uint256 i = 0; i < arr.length; i++) {
                console.log("Tick Index", int256(tickIndex)); // cast to int256 for console
                //console.log("Liquidity", arr[i].liquidity);
                console.log("Array Length", ticks[tickKeys[k]].length);
                //console.log("User:", uint160(arr[i].user)); // cast address to uint160
                console.log("");
            }
        }

        // Delete ticks
        for (uint256 k = 0; k < tickKeys.length; k++) {
            delete ticks[tickKeys[k]];
        }

        ticks[100].push(Tick(500, address(0x123)));
        ticks[-50].push(Tick(300, address(0x456)));
        ticks[100].push(Tick(200, address(0x789))); // multiple entries at same tick
        ticks[-50].push(Tick(100, address(0xabc)));

        // Log after deletion
        console.log("");
        console.log("After deletion:");
        for (uint256 k = 0; k < tickKeys.length; k++) {
            console.log("Tick Index", int256(tickKeys[k]));
            console.log("Array Length", ticks[tickKeys[k]].length); // should be 0
            console.log("");
        }

        for (uint256 k = 0; k < tickKeys.length; k++) {
            delete ticks[tickKeys[k]];
        }

        // Log after deletion
        console.log("");
        console.log("After second deletion:");
        for (uint256 k = 0; k < tickKeys.length; k++) {
            console.log("Tick Index", int256(tickKeys[k]));
            console.log("Array Length", ticks[tickKeys[k]].length); // should be 0
            console.log("");
        }
    }
}
