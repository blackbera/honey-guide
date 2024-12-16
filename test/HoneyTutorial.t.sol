// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {HoneyTutorial} from "../src/HoneyTutorial.sol";
import {HoneyFactory} from "../lib/contracts-monorepo/src/honey/HoneyFactory.sol";
import {Honey} from "../lib/contracts-monorepo/src/honey/Honey.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";

contract HoneyTutorialTest is Test {
    HoneyTutorial public tutorial;
    HoneyFactory public factory;
    Honey public honey;
    
    // Mainnet addresses
    address public constant USDC = 0x015fd589F4f1A33ce4487E12714e1B15129c9329;
    
    // Berachain roles
    bytes32 public constant MANAGER_ROLE = 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08;
    address public constant MANAGER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address public user = address(2);

    // Contract addresses
    address public constant HONEY = 0xd137593CDB341CcC78426c54Fb98435C60Da193c;
    address public constant HONEY_FACTORY = 0xA81F0019d442f19f66880bcf2698B4E5D5Ec249A;

    // Fork setup
    uint256 forkId;

    function setUp() public {
        // Create a fork of Berachain
        forkId = vm.createFork("https://rpc.berachain.com");
        vm.selectFork(forkId);
        
        // Get the deployed contracts
        factory = HoneyFactory(HONEY_FACTORY);
        honey = Honey(HONEY);

        // Deploy our tutorial contract
        tutorial = new HoneyTutorial(HONEY_FACTORY, HONEY);

        // Deal some tokens to our test user
        deal(USDC, user, 1000000 * 1e6);  // 1M USDC

        // Setup necessary permissions
        vm.startPrank(MANAGER);
        factory.setMintRate(USDC, 0.98e18); // 98% mint rate
        factory.setRedeemRate(USDC, 0.98e18); // 98% redeem rate
        vm.stopPrank();
    }

    function test_BasicModeMinting() public {
        vm.startPrank(user);
        
        // Approve tutorial contract to spend USDC
        uint256 mintAmount = 1000 * 1e6; // 1000 USDC
        ERC20(USDC).approve(address(tutorial), mintAmount);

        // Mint Honey using USDC
        uint256 honeyMinted = tutorial.mintBasicMode(USDC, mintAmount);
        
        // Verify Honey was minted
        assertGt(honeyMinted, 0, "Should have minted some Honey");
        assertEq(honey.balanceOf(user), honeyMinted, "User should have received Honey");

        vm.stopPrank();
    }

    function test_BasicModeRedeeming() public {
        vm.startPrank(user);
        
        // First mint some Honey
        uint256 mintAmount = 1000 * 1e6; // 1000 USDC
        ERC20(USDC).approve(address(tutorial), mintAmount);
        uint256 honeyMinted = tutorial.mintBasicMode(USDC, mintAmount);
        
        // Now redeem the Honey
        honey.approve(address(tutorial), honeyMinted);
        uint256[] memory redeemedAmount = tutorial.redeemBasicMode(USDC, honeyMinted);
        
        // Verify redemption
        assertGt(redeemedAmount[0], 0, "Should have redeemed some USDC");
        
        vm.stopPrank();
    }

    function test_BasketModeMinting() public {
        // Setup basket mode
        vm.startPrank(MANAGER);
        factory.setForcedBasketMode(true);
        vm.stopPrank();

        vm.startPrank(user);
        
        // Approve tutorial contract to spend tokens
        uint256 mintAmount = 1000 * 1e6; // 1000 USDC
        ERC20(USDC).approve(address(tutorial), mintAmount);

        // Mint Honey in basket mode
        uint256 honeyMinted = tutorial.mintBasketMode(USDC, mintAmount);
        
        // Verify Honey was minted
        assertGt(honeyMinted, 0, "Should have minted some Honey");
        assertEq(honey.balanceOf(user), honeyMinted, "User should have received Honey");

        vm.stopPrank();
    }

    function test_BasketModeRedeeming() public {
        // Setup basket mode
        vm.startPrank(MANAGER);
        factory.setForcedBasketMode(true);
        vm.stopPrank();

        vm.startPrank(user);
        
        // First mint some Honey in basket mode
        uint256 mintAmount = 1000 * 1e6; // 1000 USDC
        ERC20(USDC).approve(address(tutorial), mintAmount);
        uint256 honeyMinted = tutorial.mintBasketMode(USDC, mintAmount);
        
        // Now redeem the Honey
        honey.approve(address(tutorial), honeyMinted);
        uint256[] memory redeemedAmounts = tutorial.redeemBasketMode(USDC, honeyMinted);
        
        // Verify redemption
        assertGt(redeemedAmounts.length, 0, "Should have redeemed some collateral");
        
        vm.stopPrank();
    }

    function test_CheckBasketMode() public {
        // Initially should be in basic mode
        assertFalse(tutorial.isBasketMode(true), "Should not be in basket mode for minting");
        assertFalse(tutorial.isBasketMode(false), "Should not be in basket mode for redeeming");

        // Enable basket mode
        vm.prank(MANAGER);
        factory.setForcedBasketMode(true);

        // Should now be in basket mode
        assertTrue(tutorial.isBasketMode(true), "Should be in basket mode for minting");
        assertTrue(tutorial.isBasketMode(false), "Should be in basket mode for redeeming");
    }
} 