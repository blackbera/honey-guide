// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {HoneyMinter} from "../src/HoneyMinter.sol";
import {HoneyFactory} from "../lib/contracts-monorepo/src/honey/HoneyFactory.sol";
import {HoneyFactoryReader} from "../lib/contracts-monorepo/src/honey/HoneyFactoryReader.sol";
import {Honey} from "../lib/contracts-monorepo/src/honey/Honey.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";

contract HoneyTutorialTest is Test {
    HoneyMinter public minter;
    HoneyFactory public factory;
    HoneyFactoryReader public factoryReader;
    Honey public honey;
    
    address public constant USDT = 0x015fd589F4f1A33ce4487E12714e1B15129c9329;
    address public constant USDC = 0x164A2dE1bc5dc56F329909F7c97Bae929CaE557B;
    address public constant HONEY = 0xd137593CDB341CcC78426c54Fb98435C60Da193c;
    address public constant HONEY_FACTORY = 0xA81F0019d442f19f66880bcf2698B4E5D5Ec249A;
    address public constant FACTORY_READER = 0x8C4A67395d60D235827F5edE446941E84d30a5B1;
    
    address public user = address(2);

    // Fork setup
    uint256 forkId;

    function setUp() public {
        // Cartio fork
        forkId = vm.createFork("https://rockbeard-eth-cartio.berachain.com");
        vm.selectFork(forkId);
        
        // Get the deployed contracts
        factory = HoneyFactory(HONEY_FACTORY);
        factoryReader = HoneyFactoryReader(FACTORY_READER);
        honey = Honey(HONEY);
        
        // Deploy our tutorial contract
        minter = new HoneyMinter(HONEY_FACTORY, HONEY);

        // Deal some tokens to our test user
        deal(USDT, user, 1000000 * 1e6);  // 1M USDT
        deal(USDC, user, 1000000 * 1e6);  // 1M USDC
    }

    function test_BasicModeMinting() public {
        vm.startPrank(user);
        
        // Check if we're in basket mode
        bool isBasketMode = factory.isBasketModeEnabled(true);
        console2.log("Is basket mode enabled:", isBasketMode);

        // Preview the mint amount
        uint256 mintAmount = 1000 * 1e6; // 1000 USDT
        uint256 expectedHoney = factoryReader.previewMint(USDT, mintAmount);
        console2.log("Expected Honey from mint:", expectedHoney);
        
        // Approve the tutorial contract to spend both USDT and USDC
        ERC20(USDT).approve(address(minter), mintAmount);
        ERC20(USDC).approve(address(minter), mintAmount);

        // Mint Honey using appropriate mode
        uint256 honeyMinted;
        if (isBasketMode) {
            honeyMinted = minter.mintBasketMode(USDT, mintAmount);
        } else {
            honeyMinted = minter.mintBasicMode(USDT, mintAmount);
        }
        
        // Verify Honey was minted
        assertGt(honeyMinted, 0, "Should have minted some Honey");
        assertEq(honey.balanceOf(user), honeyMinted, "User should have received Honey");
        
        vm.stopPrank();
    }

    function test_BasicModeRedeeming() public {
        // First mint some Honey
        test_BasicModeMinting();
        
        vm.startPrank(user);
        
        // Check if we're in basket mode
        bool isBasketMode = factory.isBasketModeEnabled(false);
        console2.log("Is basket mode enabled for redeem:", isBasketMode);

        // Get user's Honey balance
        uint256 honeyBalance = honey.balanceOf(user);
        console2.log("User's Honey balance:", honeyBalance);

        // Preview redeem amount
        uint256[] memory expectedRedeemAmounts;
        if (isBasketMode) {
            expectedRedeemAmounts = factoryReader.previewRedeemBasketMode(honeyBalance);
            console2.log("Expected USDT from redeem:", expectedRedeemAmounts[0]);
            console2.log("Expected USDC from redeem:", expectedRedeemAmounts[1]);
        } else {
            expectedRedeemAmounts = new uint256[](1);
            expectedRedeemAmounts[0] = factoryReader.previewRedeem(USDT, honeyBalance);
            console2.log("Expected USDT from redeem:", expectedRedeemAmounts[0]);
        }

        // Approve tutorial to spend Honey
        honey.approve(address(minter), honeyBalance);

        // Redeem Honey
        uint256[] memory redeemedAmounts;
        if (isBasketMode) {
            redeemedAmounts = minter.redeemBasketMode(USDT, honeyBalance);
        } else {
            redeemedAmounts = minter.redeemBasicMode(USDT, honeyBalance);
        }

        // Verify redemption
        assertEq(redeemedAmounts.length, 
            expectedRedeemAmounts.length, 
            "Should have received expected number of tokens");

        for (uint256 i = 0; i < redeemedAmounts.length; i++) {
            assertApproxEqRel(redeemedAmounts[i], 
                expectedRedeemAmounts[i], 
                0.01e18, 
                "Redeemed amount should match preview");
        }
        
        vm.stopPrank();
    }

} 