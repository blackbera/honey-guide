// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "solady/src/tokens/ERC20.sol";
import {HoneyFactory} from "../lib/contracts-monorepo/src/honey/HoneyFactory.sol";
import {Honey} from "../lib/contracts-monorepo/src/honey/Honey.sol";
/// @title HoneyMinter
/// @notice A simple contract demonstrating how to interact with Berachain's Honey stablecoin
/// @dev This is for educational purposes only not for production use
contract HoneyMinter {
    HoneyFactory public immutable FACTORY;
    Honey public immutable HONEY;

    error InsufficientAllowance();
    error InsufficientBalance();
    error TransferFailed();

    constructor(address _factory, address _honey) {
        FACTORY = HoneyFactory(_factory);
        HONEY = Honey(_honey);
    }

    /// @notice Mints Honey tokens using a single collateral (non-basket mode)
    /// @param collateral The collateral token address
    /// @param amount The amount of collateral to use
    /// @return mintedAmount The amount of Honey minted
    function mintBasicMode(address collateral, uint256 amount) external returns (uint256 mintedAmount) {
        // Check allowance
        if (ERC20(collateral).allowance(msg.sender, address(this)) < amount) {
            revert InsufficientAllowance();
        }
        
        // Check balance
        if (ERC20(collateral).balanceOf(msg.sender) < amount) {
            revert InsufficientBalance();
        }

        // Transfer collateral to this contract
        bool success = ERC20(collateral).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        // Approve factory to spend collateral
        ERC20(collateral).approve(address(FACTORY), amount);

        // Mint Honey - note: we expect non-basket mode (false)
        mintedAmount = FACTORY.mint(collateral, amount, msg.sender, false);
    }

    /// @notice Redeems Honey tokens for a single collateral (non-basket mode)
    /// @param collateral The collateral token to receive
    /// @param honeyAmount The amount of Honey to redeem
    /// @return redeemedAmount The amount of collateral received
    function redeemBasicMode(address collateral, uint256 honeyAmount) 
        external 
        returns (uint256[] memory redeemedAmount) 
    {
        // Check allowance
        if (HONEY.allowance(msg.sender, address(this)) < honeyAmount) {
            revert InsufficientAllowance();
        }

        // Check balance
        if (HONEY.balanceOf(msg.sender) < honeyAmount) {
            revert InsufficientBalance();
        }

        // Transfer Honey to this contract
        bool success = HONEY.transferFrom(msg.sender, address(this), honeyAmount);
        if (!success) revert TransferFailed();

        // Approve factory to spend Honey
        HONEY.approve(address(FACTORY), honeyAmount);

        // Redeem Honey - note: we expect non-basket mode (false)
        redeemedAmount = FACTORY.redeem(collateral, honeyAmount, msg.sender, false);
    }

    /// @notice Mints Honey tokens using multiple collaterals (basket mode)
    /// @param collateral The reference collateral token address
    /// @param amount The amount of reference collateral
    /// @return mintedAmount The amount of Honey minted
    function mintBasketMode(address collateral, uint256 amount) external returns (uint256 mintedAmount) {
        // First check if basket mode is enabled for minting
        require(FACTORY.isBasketModeEnabled(true), "Basket mode not enabled");

        // Get all registered assets
        uint256 numAssets = FACTORY.numRegisteredAssets();
        for(uint256 i = 0; i < numAssets; i++) {
            address asset = FACTORY.registeredAssets(i);
            
            // Check allowance for each asset
            if (ERC20(asset).allowance(msg.sender, address(this)) < amount) {
                revert InsufficientAllowance();
            }

            // Transfer asset to this contract
            bool success = ERC20(asset).transferFrom(msg.sender, address(this), amount);
            if (!success) revert TransferFailed();

            // Approve factory to spend asset
            ERC20(asset).approve(address(FACTORY), amount);
        }

        // Mint Honey - note: we expect basket mode (true)
        mintedAmount = FACTORY.mint(collateral, amount, msg.sender, true);
    }

    /// @notice Redeems Honey tokens for multiple collaterals (basket mode)
    /// @param collateral The reference collateral token address
    /// @param honeyAmount The amount of Honey to redeem
    /// @return redeemedAmounts Array of redeemed collateral amounts
    function redeemBasketMode(address collateral, uint256 honeyAmount) 
        external 
        returns (uint256[] memory redeemedAmounts) 
    {
        // First check if basket mode is enabled for redeeming
        require(FACTORY.isBasketModeEnabled(false), "Basket mode not enabled");

        // Check allowance
        if (HONEY.allowance(msg.sender, address(this)) < honeyAmount) {
            revert InsufficientAllowance();
        }

        // Check balance
        if (HONEY.balanceOf(msg.sender) < honeyAmount) {
            revert InsufficientBalance();
        }

        // Transfer Honey to this contract
        bool success = HONEY.transferFrom(msg.sender, address(this), honeyAmount);
        if (!success) revert TransferFailed();

        // Approve factory to spend Honey
        HONEY.approve(address(FACTORY), honeyAmount);

        // Redeem Honey - note: we expect basket mode (true)
        redeemedAmounts = FACTORY.redeem(collateral, honeyAmount, msg.sender, true);
    }

    /// @notice Checks if basket mode is enabled for minting or redeeming
    /// @param isMint True to check mint mode, false to check redeem mode
    /// @return True if basket mode is enabled
    function isBasketMode(bool isMint) external view returns (bool) {
        return FACTORY.isBasketModeEnabled(isMint);
    }
} 