// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Diamond} from "../src/Diamond.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/facets/OwnershipFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import "../src/facets/SpotFacetV2.sol";
import "../src/facets/FactoryFacet.sol";
import "../src/facets/OracleFacet.sol";
import "../src/facets/RolesFacet.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface ISpotFacet {
    function openPosition(
        address asset,
        uint256 marginAmount,
        uint16 leverage,
        bool isLong,
        uint16 maxSlippageBps,
        bool reduceOnly,
        uint256 expireTime,
        uint256 priceLimit,
        uint256 actualPrice,
        uint256 triggerPrice
    ) external;
}

// Real PulseX V2 router and pool addresses
IUniswapV2Router constant router = IUniswapV2Router(0x165C3410fC91EF562C50559f7d2289fEbed552d9);
IERC20 constant dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
IERC20 constant asset = IERC20(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);

contract SpotTest is Test {
    Diamond diamond;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    OwnershipFacet ownershipFacet;
    SpotFacetV2 spotFacet;
    VaultFactoryFacet factoryFacet;
    OracleFacet oracleFacet;
    RolesFacet rolesFacet;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    address whale = address(0x999); // arbitrary whale for testing
    address owner = msg.sender;

    function setUp() public {
        vm.startPrank(owner);
        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        spotFacet = new SpotFacetV2();
        factoryFacet = new VaultFactoryFacet();

        // Deploy diamond with diamondCutFacet
        diamond = new Diamond(owner, address(diamondCutFacet));
        console.log("Diamond deployed at:", address(diamond));

        // Deploy ExampleFacet
        // pauseFacet = new PauseFacet();
        // factoryFacet = new VaultFactoryFacet();
        //spotFacet = new SpotFacet();
        rolesFacet = new RolesFacet();
        oracleFacet = new OracleFacet();

        // Prepare cut struct
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](6);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getSelectors("DiamondLoupeFacet")
        });
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getSelectors("OwnershipFacet")
        });
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(spotFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getSelectors("SpotFacetV2")
        });
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(factoryFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getSelectors("VaultFactoryFacet")
        });
        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(oracleFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getSelectors("OracleFacet")
        });
        cut[5] = IDiamondCut.FacetCut({
            facetAddress: address(rolesFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getSelectors("RolesFacet")
        });

        // Apply cut
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        vm.deal(whale, 100 ether); // Fund whale with ETH for gas

        deal(address(dai), whale, 1e35);
        deal(address(asset), whale, 1e35);

        // bytes32 slot = keccak256("diamond.standard.spot.storage");
        // bytes32 value = vm.load(address(diamond), slot);
        // console.logBytes32(value);

        // bytes32 slot = keccak256(
        //     abi.encode(
        //         dai, // asset address or mapping key
        //         uint256(SPOT_STORAGE_POSITION) + 2 // base storage position of the mapping/struct
        //     )
        // );

        // bytes32 value = vm.load(address(diamond), slot);

        // console.log("Storage at slot:", vm.toString(slot));
        // console.log("Value at slot:", vm.toString(value));

        //bytes memory data;

        (bool success, bytes memory data) = address(diamond).call(
            abi.encodeWithSignature("createMarket(address,string,string)", dai, "DAI Vault", "DAI-VLT")
        );
        require(success, "Market creation failed");

        (success, data) = address(diamond).call(abi.encodeWithSignature("getMarket(address)", dai));
        require(success, "Get Market failed");

        // Decode the returned address
        address vaultAddress = abi.decode(data, (address));

        // Print it (if in a test)
        //console.log("Vault address:", vaultAddress);

        (success, data) = address(diamond).call(abi.encodeWithSignature("marketExists(address)", dai));
        require(success, "Market Exists failed");

        // slot = keccak256("diamond.standard.spot.storage");
        // value = vm.load(address(diamond), slot);
        // console.logBytes32(value);

        // bytes32 slot = keccak256("diamond.standard.spot.storage");
        // bytes32 value = vm.load(address(diamond), slot);
        // console.logBytes32(value);

        // Decode the returned bool
        //bool exists = abi.decode(data, (bool));

        // Now you can use it or print it
        //console.log("Market exists:", exists);

        (success, data) = address(diamond).call(abi.encodeWithSignature("setMaxLeverage(address,uint8)", dai, 30));
        require(success, "Set Max Leverage failed"); //sets vault to 1e dont know why

        (success, data) = address(diamond).call(abi.encodeWithSignature("getMaxLeverage(address)", dai));
        require(success, "Get Max Leverage failed");

        uint8 leverage = abi.decode(data, (uint8));
        console.log("Max leverage for DAI:", leverage);

        (success, data) =
            address(diamond).call(abi.encodeWithSignature("grantRole(bytes32,address)", ORACLE_ROLE, owner));
        require(success, "Call failed");

        (success, data) = address(diamond).call(abi.encodeWithSignature("setPrice(address,uint256)", dai, 1e18));
        require(success, "Set price Failed");

        vm.stopPrank();

        vm.startPrank(whale);
        dai.approve(address(vaultAddress), type(uint256).max);
        dai.approve(address(diamond), type(uint256).max);
        asset.approve(address(router), type(uint256).max);
        IERC4626 vault = IERC4626(vaultAddress);

        vault.deposit(1e24, whale); // Deposit 1 DAI from whale to vault

        vm.stopPrank();
    }

    function _getSelectors(string memory facetName) internal pure returns (bytes4[] memory selectors) {
        if (keccak256(bytes(facetName)) == keccak256(bytes("DiamondLoupeFacet"))) {
            selectors = new bytes4[](4);
            selectors[0] = bytes4(keccak256("facets()"));
            selectors[1] = bytes4(keccak256("facetFunctionSelectors(address)"));
            selectors[2] = bytes4(keccak256("facetAddresses()"));
            selectors[3] = bytes4(keccak256("facetAddress(bytes4)"));
        } else if (keccak256(bytes(facetName)) == keccak256(bytes("OwnershipFacet"))) {
            selectors = new bytes4[](2);
            selectors[0] = bytes4(keccak256("owner()"));
            selectors[1] = bytes4(keccak256("transferOwnership(address)"));
        } else if (keccak256(bytes(facetName)) == keccak256(bytes("SpotFacetV2"))) {
            selectors = new bytes4[](1);
            selectors[0] = bytes4(
                keccak256("openPosition(address,uint256,uint16,bool,uint16,bool,uint256,uint256,uint256,uint256)")
            );
        } else if (keccak256(bytes(facetName)) == keccak256(bytes("VaultFactoryFacet"))) {
            selectors = new bytes4[](5);
            selectors[0] = bytes4(keccak256("createMarket(address,string,string)"));
            selectors[1] = bytes4(keccak256("getMarket(address)"));
            selectors[2] = bytes4(keccak256("marketExists(address)"));
            selectors[3] = bytes4(keccak256("setMaxLeverage(address,uint8)"));
            selectors[4] = bytes4(keccak256("getMaxLeverage(address)"));
        } else if (keccak256(bytes(facetName)) == keccak256(bytes("OracleFacet"))) {
            selectors = new bytes4[](1);
            selectors[0] = bytes4(keccak256("setPrice(address,uint256)"));
        } else if (keccak256(bytes(facetName)) == keccak256(bytes("RolesFacet"))) {
            selectors = new bytes4[](2);
            selectors[0] = bytes4(keccak256("hasRole(bytes32,address)"));
            selectors[1] = bytes4(keccak256("grantRole(bytes32,address)"));
        } else {
            revert("Unknown facet");
        }
    }

    // function testWhaleBalance() public view {
    //     uint256 daiBalance = dai.balanceOf(whale);
    //     uint256 assetBalance = asset.balanceOf(whale);
    //     assert(daiBalance == 1e35);
    //     assert(assetBalance == 1e35);
    // }

    function testSlippage() public {
        vm.startPrank(whale);
        dai.approve(address(router), type(uint256).max);
        asset.approve(address(router), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(dai);
        path[1] = address(asset);

        uint256 amountIn = 1e18; // 1 DAI
        uint256 amountOutMin = 0; // No slippage check for simplicity

        uint256[] memory amounts =
            router.swapExactTokensForTokens(amountIn, amountOutMin, path, whale, block.timestamp + 1 hours);

        assert(amounts[1] > 0); // Ensure we received some asset
        vm.stopPrank();
    }

    // function testInspectStorage() public view {
    //     bytes32 slot = keccak256("diamond.standard.spot.storage");
    //     bytes32 value = vm.load(address(diamond), slot);
    //     console.logBytes32(value);
    // }

    // function testReadExactSlot() public view {
    //     // The slot you want to inspect
    //     bytes32 slot = keccak256(
    //         abi.encode(
    //             dai, // asset address or mapping key
    //             uint256(SPOT_STORAGE_POSITION) + 2 // base storage position of the mapping/struct
    //         )
    //     );

    //     bytes32 value = vm.load(address(diamond), slot);

    //     console.log("Storage at slot:", vm.toString(slot));
    //     console.log("Value at slot:", vm.toString(value));
    // }

    function testOpenPosition() public {
        vm.startPrank(whale);
        dai.approve(address(router), type(uint256).max);
        asset.approve(address(router), type(uint256).max);

        (bool success, bytes memory data) = address(diamond).call(abi.encodeWithSignature("marketExists(address)", dai));
        require(success, "Market Exists failed");

        bool exists = abi.decode(data, (bool));

        console.log("Market exists:", exists);

        //ILendingPool lendingPool = ILendingPool(LibFactory.getMarket(address(dai)));

        ISpotFacet(address(diamond)).openPosition(
            address(dai), // asset
            100, // marginAmount
            10, // leverage
            true, // isLong
            1000, // maxSlippageBps
            false, // reduceOnly
            block.timestamp + 1 hours, // expireTime
            1, // priceLimit
            1, // actualPrice
            1 // triggerPrice
        );

        // (success, data) = address(diamond).call(
        //     abi.encodeWithSignature(
        //         "openPosition(address,uint256,uint16,bool,uint16,bool,uint256,uint256,uint256,uint256)",
        //         address(dai),
        //         1,
        //         10,
        //         true,
        //         1000,
        //         false,
        //         block.timestamp + 1 hours,
        //         0,
        //         0,
        //         0
        //     )
        // );
        // require(success, "open position failed");

        vm.stopPrank();
    }
}
