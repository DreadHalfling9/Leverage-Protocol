// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library LibOracle {
    bytes32 constant ORACLE_STORAGE_POSITION = keccak256("diamond.standard.oracle.storage");

    struct PriceData {
        uint256 price;
        uint256 timestamp;
    }

    struct OracleStorage {
        mapping(address => PriceData) prices;
    }

    function oracleStorage() internal pure returns (OracleStorage storage os) {
        bytes32 position = ORACLE_STORAGE_POSITION;
        assembly {
            os.slot := position
        }
    }

    function getPrice(address token) internal view returns (uint256 price, uint256 timestamp) {
        OracleStorage storage os = oracleStorage();
        PriceData storage data = os.prices[token];
        return (data.price, data.timestamp);
    }

    function setPrice(address token, uint256 price) internal {
        OracleStorage storage os = oracleStorage();
        os.prices[token] = PriceData({price: price, timestamp: block.timestamp});
    }

    function isPriceStale(address token, uint256 maxAge) internal view returns (bool) {
        OracleStorage storage os = oracleStorage();
        uint256 lastUpdate = os.prices[token].timestamp;
        return (block.timestamp - lastUpdate) > maxAge;
    }
}
