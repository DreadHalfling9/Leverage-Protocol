// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library LibPause {
    bytes32 constant PAUSE_STORAGE_POSITION = keccak256("diamond.standard.pause.storage");

    struct PauseStorage {
        bool paused;
    }

    function pauseStorage() internal pure returns (PauseStorage storage ps) {
        bytes32 position = PAUSE_STORAGE_POSITION;
        assembly {
            ps.slot := position
        }
    }

    function isPaused() internal view returns (bool) {
        return pauseStorage().paused;
    }

    function setPaused(bool _paused) internal {
        pauseStorage().paused = _paused;
    }
}
