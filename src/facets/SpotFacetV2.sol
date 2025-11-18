// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";

import {LibDiamond} from "../libraries/LibDiamond.sol";
import "../libraries/LibOracle.sol";
import "../libraries/LibSpot.sol";
import "../libraries/LibFactory.sol";
import "../libraries/LibRoles.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface ILendingPool {
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function addBadDebt(uint256 amount) external;
    function availableLiquidity() external view returns (uint256);
}

contract SpotFacetV2 {
    address internal constant dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI from ethereum
    address internal constant router = 0x165C3410fC91EF562C50559f7d2289fEbed552d9; // Pulsex router address

    function openPosition(
        address asset,
        uint256 marginAmount,
        uint16 leverage,
        bool isLong,
        uint16 maxSlippageBps,
        bool reduceOnly,
        uint256 expireTime,
        uint256 priceLimit, //change
        uint256 actualPrice, //change
        uint256 triggerPrice //change
    ) external {
        LibSpot.createOrder(
            asset,
            isLong,
            marginAmount * leverage,
            triggerPrice,
            priceLimit,
            maxSlippageBps,
            marginAmount,
            true, // isActive
            reduceOnly,
            expireTime
        );

        // console.log("Message sender address", msg.sender);
        // console.log("Contract address", address(this));

        // (bool success, bytes memory data) = address(0x50EEf481cae4250d252Ae577A09bF514f224C6C4).call(
        //     abi.encodeWithSignature("marketExists(address)", asset)
        // );
        // require(success, "Market Exists failed");

        // // Decode the returned bool
        // bool exists = abi.decode(data, (bool));

        // console.log("Market exists:", exists);

        // console.log("Market exists:", LibFactory.marketExists(asset));

        // console.log(LibSpot.getMaxLeverage(asset)); //this is zero, why?

        require(marginAmount * leverage > 100, "Postion size too small");
        require(expireTime > block.timestamp, "Order expiry must be in the future");
        require(marginAmount > 0, "Margin amount must be greater than zero");
        require(leverage > 0 && leverage <= LibSpot.getMaxLeverage(asset), "Leverage out of bounds");
        require(maxSlippageBps <= 10000, "Max slippage too high");
        require(priceLimit > 0, "Price limit must be greater than zero");
        require(actualPrice > 0, "Actual price must be greater than zero");

        //require(!isUnderwater(LibSpot.positions[msg.sender]));

        uint256 borrowAmount = marginAmount * (leverage - 1);
        require(ILendingPool(LibFactory.getMarket(asset)).availableLiquidity() >= borrowAmount, "Not enough liquidity");
        _checkSlippage(isLong, actualPrice, priceLimit, maxSlippageBps);
        require(IERC20(asset).transferFrom(msg.sender, address(this), marginAmount), "Transfer failed");

        ILendingPool(LibFactory.getMarket(asset)).borrow(borrowAmount);
        _checkSlippage(isLong, actualPrice, priceLimit, maxSlippageBps);
    }

    function closePosition() public {}

    function _checkSlippage(bool isLong, uint256 actualPrice, uint256 priceLimit, uint256 maxSlippage) internal pure {
        if (isLong) {
            uint256 maxAllowed = priceLimit * (10_000 + maxSlippage) / 10_000;
            require(actualPrice <= maxAllowed, "Slippage too high for long");
        } else {
            uint256 minAllowed = priceLimit * (10_000 - maxSlippage) / 10_000;
            require(actualPrice >= minAllowed, "Slippage too high for short");
        }
    }

    function getExpectedSwap(address asset, uint256 amountIn) external view returns (uint256) {
        address[] memory path = LibSpot.getPath(asset);
        uint256[] memory amounts = IUniswapV2Router(router).getAmountsOut(amountIn, path);
        return amounts[amounts.length - 1];
    }

    function isUnderwater(LibSpot.Position memory pos) internal view returns (bool) {
        (uint256 oraclePrice,) = LibOracle.getPrice(pos.asset);
        require(oraclePrice > 0, "Spot: Invalid oracle price");
        require(pos.leverage > 0, "Spot: Invalid leverage");

        uint256 notional = pos.size;
        uint256 currentValue = pos.isLong ? (pos.size * oraclePrice) / 1e18 : (pos.size * 1e18) / oraclePrice;

        // Equity = margin + PnL
        uint256 equity;
        if (currentValue >= notional) {
            equity = pos.margin + (currentValue - notional);
        } else {
            equity = pos.margin > (notional - currentValue) ? pos.margin - (notional - currentValue) : 0;
        }

        uint256 maintenanceMargin = notional / pos.leverage;
        return equity < maintenanceMargin;
    }
}
