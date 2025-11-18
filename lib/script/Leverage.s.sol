// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import {Diamond} from "../src/Diamond.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/facets/OwnershipFacet.sol";
import {VaultFactoryFacet} from "../src/facets/FactoryFacet.sol";
import {SpotFacet} from "../src/facets/SpotFacet.sol";
import {PauseFacet} from "../src/facets/PauseFacet.sol";
import {RolesFacet} from "../src/facets/RolesFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";

contract DiamondDeploy is Script {
    function run() external {
        vm.startBroadcast();

        address owner = msg.sender;

        // 1️⃣ Deploy facets
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        VaultFactoryFacet factoryFacet = new VaultFactoryFacet();
        SpotFacet spotFacet = new SpotFacet();
        PauseFacet pauseFacet = new PauseFacet();
        RolesFacet rolesFacet = new RolesFacet();

        // 2️⃣ Deploy the Diamond
        Diamond diamond = new Diamond(owner, address(diamondCutFacet));

        // 3️⃣ Prepare the cuts
        IDiamondCut.FacetCut;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsDiamondLoupe()
        });

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsOwnership()
        });

        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(factoryFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsFactory()
        });

        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(spotFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsSpot()
        });

        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(pauseFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsPause()
        });

        cut[5] = IDiamondCut.FacetCut({
            facetAddress: address(rolesFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsRoles()
        });

        console.logBytes(abi.encodeWithSelector(IDiamondCut.diamondCut.selector, cut, address(0), ""));

        // 4️⃣ Execute diamondCut
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        vm.stopBroadcast();
    }

    // ----------------------
    // Selector helpers
    // ----------------------
    function getSelectorsDiamondLoupe() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4;
        selectors[0] = bytes4(keccak256("facets()"));
        selectors[1] = bytes4(keccak256("facetFunctionSelectors(address)"));
        selectors[2] = bytes4(keccak256("facetAddresses()"));
        selectors[3] = bytes4(keccak256("facetAddress(bytes4)"));
    }

    function getSelectorsOwnership() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4;
        selectors[0] = bytes4(keccak256("owner()"));
        selectors[1] = bytes4(keccak256("transferOwnership(address)"));
    }

    function getSelectorsFactory() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4;
        selectors[0] = bytes4(keccak256("getVault(address)"));
    }

    function getSelectorsSpot() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4;
        selectors[0] = bytes4(keccak256("someSpotFunction()"));
    }

    function getSelectorsPause() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4;
        selectors[0] = bytes4(keccak256("pause()"));
        selectors[1] = bytes4(keccak256("unpause()"));
        selectors[2] = bytes4(keccak256("paused()"));
    }

    function getSelectorsRoles() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4;
        selectors[0] = bytes4(keccak256("hasRole(bytes32,address)"));
        selectors[1] = bytes4(keccak256("grantRole(bytes32,address)"));
    }
}
