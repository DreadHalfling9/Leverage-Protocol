// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// /// @notice Minimal ERC20 for testing with mint/burn
// contract MockERC20 {
//     string public name;
//     string public symbol;
//     uint8 public decimals = 18;
//     uint256 public totalSupply;

//     mapping(address => uint256) public balanceOf;
//     mapping(address => mapping(address => uint256)) public allowance;

//     constructor(string memory _name, string memory _symbol) {
//         name = _name;
//         symbol = _symbol;
//     }

//     function approve(address spender, uint256 amount) external returns (bool) {
//         allowance[msg.sender][spender] = amount;
//         return true;
//     }

//     function transfer(address to, uint256 amount) external returns (bool) {
//         _transfer(msg.sender, to, amount);
//         return true;
//     }

//     function transferFrom(address from, address to, uint256 amount) external returns (bool) {
//         uint256 allowed = allowance[from][msg.sender];
//         require(allowed >= amount, "ERC20: allowance");
//         allowance[from][msg.sender] = allowed - amount;
//         _transfer(from, to, amount);
//         return true;
//     }

//     function mint(address to, uint256 amount) external {
//         totalSupply += amount;
//         balanceOf[to] += amount;
//     }

//     function burn(address from, uint256 amount) external {
//         require(balanceOf[from] >= amount, "ERC20: burn exceed");
//         balanceOf[from] -= amount;
//         totalSupply -= amount;
//     }

//     function _transfer(address from, address to, uint256 amount) internal {
//         require(balanceOf[from] >= amount, "ERC20: balance");
//         balanceOf[from] -= amount;
//         balanceOf[to] += amount;
//     }
// }

// /// @notice Simple UniswapV2-style Router mock
// /// - Uses internal reserves mapping for token pairs (tokenA, tokenB) keyed by keccak(tokenA,tokenB)
// /// - getAmountOut uses the real Uniswap V2 formula with 0.3% fee
// /// - swapExactTokensForTokens transfers input token from caller to router and sends final output to `to`
// /// - supports multi-hop by updating internal reserves each hop
// contract MockUniswapV2Router {
//     struct Reserves {
//         uint112 reserve0;
//         uint112 reserve1;
//         bool exists;
//     }

//     // Pair key is keccak(token0, token1) where token0 < token1 by address
//     mapping(bytes32 => Reserves) public reserves;

//     event ReservesSet(address tokenA, address tokenB, uint256 reserveA, uint256 reserveB);
//     event SwapExecuted(address indexed sender, address[] path, uint256 amountIn, uint256 amountOut);

//     /// @dev helper to compute canonical ordering and mapping key
//     function _pairKey(address tokenA, address tokenB)
//         internal
//         pure
//         returns (address token0, address token1, bytes32 key)
//     {
//         if (tokenA < tokenB) {
//             token0 = tokenA;
//             token1 = tokenB;
//         } else {
//             token0 = tokenB;
//             token1 = tokenA;
//         }
//         key = keccak256(abi.encodePacked(token0, token1));
//     }

//     /// @notice Admin/test helper: set reserves for a pair. Caller must have transferred tokens to this contract beforehand if you want balances to match numbers.
//     /// @dev For tests it's easiest to mint tokens to this contract or transfer to it so balances align.
//     function setReserves(address tokenA, address tokenB, uint256 reserveA, uint256 reserveB) external {
//         (address token0, address token1, bytes32 key) = _pairKey(tokenA, tokenB);
//         // store in token0/token1 order; map the reserves accordingly
//         if (tokenA == token0) {
//             reserves[key] = Reserves({reserve0: uint112(reserveA), reserve1: uint112(reserveB), exists: true});
//         } else {
//             reserves[key] = Reserves({reserve0: uint112(reserveB), reserve1: uint112(reserveA), exists: true});
//         }
//         emit ReservesSet(tokenA, tokenB, reserveA, reserveB);
//     }

//     /// @notice Returns amountOut for an input amount using UniswapV2 formula (0.3% fee)
//     function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
//         require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
//         require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
//         uint256 amountInWithFee = amountIn * 997;
//         uint256 numerator = amountInWithFee * reserveOut;
//         uint256 denominator = (reserveIn * 1000) + amountInWithFee;
//         return numerator / denominator;
//     }

//     /// @notice Swap supporting multi-hop paths, returns amounts array like real router
//     /// @param amountIn exact input amount (caller must approve this router for path[0])
//     function swapExactTokensForTokens(
//         uint256 amountIn,
//         uint256 amountOutMin,
//         address[] calldata path,
//         address to,
//         uint256 /* deadline - unused in mock */
//     ) external returns (uint256[] memory amounts) {
//         require(path.length >= 2, "MockRouter: INVALID_PATH");

//         // Pull amountIn of path[0] from msg.sender into this router
//         MockERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

//         amounts = new uint256[](path.length);
//         amounts[0] = amountIn;

//         // iterate hops
//         for (uint256 i = 0; i < path.length - 1; i++) {
//             address input = path[i];
//             address output = path[i + 1];

//             (address token0,, bytes32 key) = _pairKey(input, output);
//             require(reserves[key].exists, "MockRouter: NO_PAIR");

//             // resolve reserve order to match input/output
//             uint112 reserveIn;
//             uint112 reserveOut;
//             bool reversed = (input != token0); // if token0 != input then reserves are stored reversed
//             if (!reversed) {
//                 reserveIn = reserves[key].reserve0;
//                 reserveOut = reserves[key].reserve1;
//             } else {
//                 reserveIn = reserves[key].reserve1;
//                 reserveOut = reserves[key].reserve0;
//             }

//             uint256 amountOut = getAmountOut(amounts[i], reserveIn, reserveOut);
//             amounts[i + 1] = amountOut;

//             // update reserves in place (simulate swap)
//             // newReserveIn = reserveIn + amountIn
//             // newReserveOut = reserveOut - amountOut
//             if (!reversed) {
//                 reserves[key].reserve0 = uint112(uint256(reserveIn) + amounts[i]);
//                 reserves[key].reserve1 = uint112(uint256(reserveOut) - amountOut);
//             } else {
//                 reserves[key].reserve1 = uint112(uint256(reserveIn) + amounts[i]);
//                 reserves[key].reserve0 = uint112(uint256(reserveOut) - amountOut);
//             }
//         }

//         // final amount is amounts[path.length - 1]
//         require(amounts[amounts.length - 1] >= amountOutMin, "MockRouter: INSUFFICIENT_OUTPUT_AMOUNT");

//         // Router must hold enough of final token to send to 'to'
//         // For simplicity we assume test setup transferred liquidity tokens to this router.
//         MockERC20(path[path.length - 1]).transfer(to, amounts[amounts.length - 1]);

//         emit SwapExecuted(msg.sender, path, amountIn, amounts[amounts.length - 1]);

//         return amounts;
//     }

//     /// @notice View helper to get reserves in the user requested order (reserve for tokenA, tokenB)
//     function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB) {
//         (address token0,, bytes32 key) = _pairKey(tokenA, tokenB);
//         require(reserves[key].exists, "MockRouter: NO_PAIR");
//         if (tokenA == token0) {
//             reserveA = reserves[key].reserve0;
//             reserveB = reserves[key].reserve1;
//         } else {
//             reserveA = reserves[key].reserve1;
//             reserveB = reserves[key].reserve0;
//         }
//     }
// }
