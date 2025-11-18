// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

// Import your diamond contracts
import {Diamond} from "../src/Diamond.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/facets/OwnershipFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import "./mocks/MockERC20.sol";
import "../src/facets/FactoryFacet.sol";
import "../src/facets/SpotFacet.sol";
import "../src/facets/PauseFacet.sol";
import "../src/facets/RolesFacet.sol";
import "../src/facets/OracleFacet.sol";

contract DiamondBasicTest is Test {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    address owner = address(0xABCD);
    address administrator = address(0x12345);
    Diamond diamond;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    OwnershipFacet ownershipFacet;
    VaultFactoryFacet factoryFacet;
    SpotFacet spotFacet;
    PauseFacet pauseFacet;
    RolesFacet rolesFacet;
    OracleFacet oracleFacet;

    function setUp() public {
        vm.startPrank(owner);
        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();

        // Deploy diamond with diamondCutFacet
        diamond = new Diamond(owner, address(diamondCutFacet));

        // Deploy ExampleFacet
        pauseFacet = new PauseFacet();
        factoryFacet = new VaultFactoryFacet();
        spotFacet = new SpotFacet();
        rolesFacet = new RolesFacet();
        oracleFacet = new OracleFacet();

        // Prepare cut struct
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](7);
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
            facetAddress: address(factoryFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getSelectors("VaultFactoryFacet")
        });
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(spotFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getSelectors("SpotFacet")
        });

        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(pauseFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getSelectors("PauseFacet")
        });
        cut[5] = IDiamondCut.FacetCut({
            facetAddress: address(rolesFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getSelectors("RolesFacet")
        });
        cut[6] = IDiamondCut.FacetCut({
            facetAddress: address(oracleFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getSelectors("OracleFacet")
        });

        //use this to get calldata for diamondCut
        //console.logBytes(abi.encodeWithSelector(IDiamondCut.diamondCut.selector, cut, address(0), ""));

        // Apply cut
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        (bool success, bytes memory data) =
            address(diamond).call(abi.encodeWithSignature("grantRole(bytes32,address)", ADMIN_ROLE, owner));
        require(success, "Call failed");

        (success, data) =
            address(diamond).call(abi.encodeWithSignature("grantRole(bytes32,address)", ORACLE_ROLE, owner));
        require(success, "Call failed");

        (success, data) =
            address(diamond).call(abi.encodeWithSignature("grantRole(bytes32,address)", ADMIN_ROLE, administrator));
        require(success, "Call failed");

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
        } else if (keccak256(bytes(facetName)) == keccak256(bytes("RolesFacet"))) {
            selectors = new bytes4[](2);
            selectors[0] = bytes4(keccak256("hasRole(bytes32,address)"));
            selectors[1] = bytes4(keccak256("grantRole(bytes32,address)"));
        } else if (keccak256(bytes(facetName)) == keccak256(bytes("VaultFactoryFacet"))) {
            selectors = new bytes4[](2);
            selectors[0] = bytes4(keccak256("getMarket(address)"));
            selectors[1] = bytes4(keccak256("createMarket(address,string,string)"));
        } else if (keccak256(bytes(facetName)) == keccak256(bytes("SpotFacet"))) {
            selectors = new bytes4[](3);
            selectors[0] = bytes4(keccak256("liquidatePosition(address user,address asset)"));
            selectors[1] = bytes4(
                keccak256(
                    "openPostion(address asset,uint256 marginAmount,uint256 leverage,bool isLong,uint256 maxSlippageBps)"
                )
            );
            selectors[2] =
                bytes4(keccak256("closePosition(address asset,uint256 leverage,bool isLong,uint256 maxSlippageBps)"));
        } else if (keccak256(bytes(facetName)) == keccak256(bytes("PauseFacet"))) {
            selectors = new bytes4[](3);
            selectors[0] = bytes4(keccak256("pause()"));
            selectors[1] = bytes4(keccak256("unpause()"));
            selectors[2] = bytes4(keccak256("paused()"));
        } else if (keccak256(bytes(facetName)) == keccak256(bytes("OracleFacet"))) {
            selectors = new bytes4[](3);
            selectors[0] = bytes4(keccak256("getPrice(address)"));
            selectors[1] = bytes4(keccak256("setPrice(address,uint256)"));
            selectors[2] = bytes4(keccak256("isPriceStale(address,uint256)"));
        }
    }

    function testOwnerIsSet() public {
        (bool success, bytes memory data) = address(diamond).call(abi.encodeWithSignature("owner()"));
        assertTrue(success);
        address currentOwner = abi.decode(data, (address));
        assertEq(currentOwner, owner);
    }

    function testOwnerTransfer() public {
        vm.startPrank(owner);

        address previousOwner = owner;
        address newOwner = address(0xDEADBEEF);
        (bool success, bytes memory data) =
            address(diamond).call(abi.encodeWithSignature("transferOwnership(address)", newOwner));
        assertTrue(success, "Transfer ownership failed");

        (success, data) = address(diamond).call(abi.encodeWithSignature("owner()"));
        assertTrue(success);
        address currentOwner = abi.decode(data, (address));
        assertEq(currentOwner, newOwner, "New owner should be set");
        assertTrue(currentOwner != previousOwner, "Previous owner should not be the current owner");
        vm.stopPrank();
    }

    function testOwnerAdmin() public {
        (bool success, bytes memory data) =
            address(diamond).call(abi.encodeWithSignature("hasRole(bytes32,address)", ADMIN_ROLE, owner));
        require(success, "Call failed");

        bool isAdmin = abi.decode(data, (bool));
        assertTrue(isAdmin);
    }

    function testIsAdmin() public {
        vm.startPrank(owner);
        (bool success, bytes memory data) =
            address(diamond).call(abi.encodeWithSignature("hasRole(bytes32,address)", ADMIN_ROLE, 0x12345));
        require(success, "Call failed");

        bool isAdmin = abi.decode(data, (bool));
        assertTrue(isAdmin, "0x12345 should have admin role");
        vm.stopPrank();
    }

    function testCallPauseFacet() public {
        vm.startPrank(owner);
        (bool success, bytes memory data) = address(diamond).call(abi.encodeWithSignature("paused()"));
        assertTrue(success);
        bool isPaused = abi.decode(data, (bool));
        assertFalse(isPaused);

        // Pause the contract
        (success,) = address(diamond).call(abi.encodeWithSignature("pause()"));
        assertTrue(success, "Pause failed");

        // Check if paused
        (success, data) = address(diamond).call(abi.encodeWithSignature("paused()"));
        assertTrue(success);
        isPaused = abi.decode(data, (bool));
        assertTrue(isPaused, "Contract should be paused");

        // Unpause the contract
        (success,) = address(diamond).call(abi.encodeWithSignature("unpause()"));
        assertTrue(success, "Unpause failed");

        // Check if unpaused
        (success, data) = address(diamond).call(abi.encodeWithSignature("paused()"));
        assertTrue(success);
        isPaused = abi.decode(data, (bool));
        assertFalse(isPaused, "Contract should be unpaused");

        vm.stopPrank();

        // Test that non-owner cannot unpause
        vm.startPrank(address(0x123456789));
        (success,) = address(diamond).call(abi.encodeWithSignature("unpause()"));
        assertFalse(success, "Non-owner should not be able to unpause");

        (success,) = address(diamond).call(abi.encodeWithSignature("pause()"));
        assertFalse(success, "Non-Admin should not be able to pause");
        vm.stopPrank();

        vm.startPrank(administrator);
        (success,) = address(diamond).call(abi.encodeWithSignature("unpause()"));
        assertFalse(success, "Non-owner should not be able to unpause");

        (success,) = address(diamond).call(abi.encodeWithSignature("pause()"));
        assertTrue(success, "Admin should be able to pause");
    }

    function testOracleFacet() public {
        vm.startPrank(owner);
        address token = address(0x1);
        uint256 price = 1000;
        bytes memory data;

        // Set price should succeed for oracle role
        (bool success,) = address(diamond).call(abi.encodeWithSignature("setPrice(address,uint256)", token, price));
        assertTrue(success, "Set price failed");

        // Get price should succeed for anyone
        (success, data) = address(diamond).call(abi.encodeWithSignature("getPrice(address)", token));
        assertTrue(success, "Get price failed");
        uint256 fetchedPrice = abi.decode(data, (uint256));
        assertEq(fetchedPrice, price, "Fetched price should match set price");

        // Check for stale price (assuming maxAge is in seconds and the price was just set)
        (success, data) = address(diamond).call(abi.encodeWithSignature("isPriceStale(address,uint256)", token, 60));
        assertTrue(success, "Check stale price failed");
        bool isStale = abi.decode(data, (bool));
        assertFalse(isStale, "Price should not be stale immediately after setting");

        vm.stopPrank();

        vm.startPrank(address(0x123456789));
        // Set price should fail for non-oracle role
        (success,) = address(diamond).call(abi.encodeWithSignature("setPrice(address,uint256)", token, price));
        assertFalse(success, "Set price should fail for non-oracle role");

        // Get price should succeed for anyone
        (success, data) = address(diamond).call(abi.encodeWithSignature("getPrice(address)", token));
        assertTrue(success, "Get price failed");
        fetchedPrice = abi.decode(data, (uint256));
        assertEq(fetchedPrice, price, "Fetched price should match set price");

        // Check for stale price (assuming maxAge is in seconds and the price was just set) should succeed for anyone
        (success, data) = address(diamond).call(abi.encodeWithSignature("isPriceStale(address,uint256)", token, 60));
        assertTrue(success, "Check stale price failed");
        isStale = abi.decode(data, (bool));
        assertFalse(isStale, "Price should not be stale immediately after setting");
    }

    function testFactoryFacet() public {
        vm.startPrank(owner);
        address market = address(0x1);
        bytes memory data;

        // Create a vault for the market
        (bool success,) =
            address(diamond).call(abi.encodeWithSignature("createMarket(address,string,string)", market, "TV1", "TS1"));
        assertTrue(success, "Create market failed");

        // Get the vault address
        (success, data) = address(diamond).call(abi.encodeWithSignature("getMarket(address)", market));
        assertTrue(success, "Get market failed");
        address vaultAddress = abi.decode(data, (address));
        assertTrue(vaultAddress != address(0), "Vault address should not be zero");

        // Calling getMarket again should return the same address
        (success, data) = address(diamond).call(abi.encodeWithSignature("getMarket(address)", market));
        assertTrue(success, "Get market failed");
        address vaultAddress2 = abi.decode(data, (address));
        assertEq(vaultAddress, vaultAddress2, "Vault addresses should match");

        vm.stopPrank();
    }

    function testVaultOwner() public {
        vm.startPrank(owner);
        bytes memory data;

        // ==== Deploy the mock asset ====
        MockERC20 asset = new MockERC20("Mock Asset", "MA", 18);
        asset.mint(owner, 1000e18);

        // Use the mock token address as the "market"
        address market = address(asset);

        // ==== Create a vault for the market ====
        (bool success,) =
            address(diamond).call(abi.encodeWithSignature("createMarket(address,string,string)", market, "TV1", "TS1"));
        assertTrue(success, "Create market failed");

        // ==== Get the vault address ====
        (success, data) = address(diamond).call(abi.encodeWithSignature("getMarket(address)", market));
        assertTrue(success, "Get vault failed");
        address vaultAddress = abi.decode(data, (address));
        assertTrue(vaultAddress != address(0), "Vault address should not be zero");

        // ==== Check the vault owner ====
        (success, data) = vaultAddress.call(abi.encodeWithSignature("owner()"));
        assertTrue(success, "Get vault owner failed");
        address vaultOwner = abi.decode(data, (address));
        assertEq(vaultOwner, address(diamond), "Vault owner should be the diamond");

        // ==== ERC4626 behavior test ====
        // Approve the vault to spend underlying
        asset.approve(vaultAddress, type(uint256).max);

        // Deposit into the vault
        uint256 depositAmount = 100e18;
        (success, data) = vaultAddress.call(abi.encodeWithSignature("deposit(uint256,address)", depositAmount, owner));
        assertTrue(success, "Deposit failed");
        uint256 sharesMinted = abi.decode(data, (uint256));

        // Shares balance should equal sharesMinted
        (success, data) = vaultAddress.call(abi.encodeWithSignature("balanceOf(address)", owner));
        assertTrue(success, "BalanceOf failed");
        uint256 balanceShares = abi.decode(data, (uint256));
        assertEq(balanceShares, sharesMinted, "Share balance mismatch");

        // Withdraw the shares
        (success, data) =
            vaultAddress.call(abi.encodeWithSignature("redeem(uint256,address,address)", sharesMinted, owner, owner));
        assertTrue(success, "Redeem failed");
        uint256 assetsWithdrawn = abi.decode(data, (uint256));
        assertEq(assetsWithdrawn, depositAmount, "Redeem did not return full amount");

        vm.stopPrank();
    }

    function testVaultAnyUser(uint256 rawUser, uint256 deposit) public {
        vm.startPrank(owner);

        // ======== Generate a fuzzed user address ========
        // Avoid address(0) and maybe the owner
        address user = address(uint160(bound(rawUser, 1, type(uint160).max)));

        // Ensure user is not the owner
        if (user == owner) {
            // Shift by 1 so it’s different
            user = address(uint160(user) + 1);
        }

        // Bound deposit to a reasonable range
        deposit = bound(deposit, 1, 1e30);

        // ==== Deploy the mock asset ====
        MockERC20 asset = new MockERC20("Mock Asset", "MA", 18);
        asset.mint(owner, 1e30);

        // Use the mock token address as the "market"
        address market = address(asset);

        // ==== Create a vault for the market ====
        (bool success,) =
            address(diamond).call(abi.encodeWithSignature("createMarket(address,string,string)", market, "TV1", "TS1"));
        assertTrue(success, "Create market failed");

        // ==== Get the vault address ====
        (, bytes memory data) = address(diamond).call(abi.encodeWithSignature("getMarket(address)", market));
        address vaultAddress = abi.decode(data, (address));

        vm.stopPrank();

        // ==== Random user ====
        vm.startPrank(user);

        // Mint tokens to the user
        asset.mint(user, deposit);

        // Approve vault
        asset.approve(vaultAddress, type(uint256).max);

        // Deposit — make sure we don’t exceed user balance
        uint256 depositAmount = deposit; // Use all minted tokens
        (success, data) = vaultAddress.call(abi.encodeWithSignature("deposit(uint256,address)", depositAmount, user));
        assertTrue(success, "User deposit failed");
        uint256 sharesMinted = abi.decode(data, (uint256));

        // Check shares balance
        (success, data) = vaultAddress.call(abi.encodeWithSignature("balanceOf(address)", user));
        uint256 shareBal = abi.decode(data, (uint256));
        assertEq(shareBal, sharesMinted, "User share balance mismatch");

        // previewDeposit check
        (success, data) = vaultAddress.call(abi.encodeWithSignature("previewDeposit(uint256)", depositAmount));
        uint256 previewShares = abi.decode(data, (uint256));
        assertEq(previewShares, sharesMinted, "previewDeposit mismatch");

        // Redeem shares (queues withdrawal)
        (success, data) =
            vaultAddress.call(abi.encodeWithSignature("redeem(uint256,address,address)", sharesMinted, user, user));
        assertTrue(success, "User redeem failed");
        uint256 queuedAmount = abi.decode(data, (uint256));
        assertEq(queuedAmount, depositAmount, "Queued withdraw amount mismatch");

        // ---- simulate cooldown period ----
        uint256 cooldown = 259200; // e.g., 3 days
        vm.warp(block.timestamp + cooldown + 1);

        // Claim withdrawal
        (success,) = vaultAddress.call(abi.encodeWithSignature("claimWithdrawal(address)", user));
        assertTrue(success, "Claim withdrawal failed");

        // Confirm user's balance
        uint256 finalBalance = asset.balanceOf(user);
        assertEq(finalBalance, deposit, "Final balance mismatch after roundtrip");

        vm.stopPrank();
    }
}
