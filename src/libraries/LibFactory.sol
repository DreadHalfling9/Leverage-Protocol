// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library LibFactory {
    bytes32 constant MARKET_STORAGE_POSITION = keccak256("diamond.standard.market.storage");

    struct MarketStorage {
        mapping(address => Market) markets;
    }

    struct Market {
        bool exists;
        address asset;
        address vault;
    }

    function marketStorage() internal pure returns (MarketStorage storage ms) {
        bytes32 position = MARKET_STORAGE_POSITION;
        assembly {
            ms.slot := position
        }
    }

    function createMarket(address asset, address vault) internal {
        require(asset != address(0), "Invalid asset");
        require(vault != address(0), "Invalid vault");
        MarketStorage storage ms = marketStorage();
        require(!ms.markets[asset].exists, "Market exists");
        ms.markets[asset] = Market({exists: true, asset: asset, vault: vault});
    }

    function marketExists(address asset) internal view returns (bool) {
        MarketStorage storage ms = marketStorage();
        return ms.markets[asset].exists;
    }

    function getMarket(address asset) internal view returns (address vault) {
        MarketStorage storage ms = marketStorage();
        require(ms.markets[asset].exists, "Market does not exist");
        vault = ms.markets[asset].vault;
        return vault;
    }
}
