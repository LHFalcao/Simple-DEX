// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleDEX is Ownable, ReentrancyGuard {
    //===================================
    // 1. VARIABLES
    //===================================

    /// @notice The ERC-20 contract for Token A.
    IERC20 public immutable tokenA;
    /// @notice The ERC-20 contract for Token B.
    IERC20 public immutable tokenB;

    /// @notice The liquidity reserve for Token A in the pool.
    uint256 public reserveA;
    /// @notice The liquidity reserve for Token B in the pool.
    uint256 public reserveB;

    //===================================
    // 2. EVENTS
    //===================================

    /// @notice Emitted when liquidity is added to the pool.
    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB
    );

    /// @notice Emitted when liquidity is removed from the pool.
    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB
    );

    /// @notice Emitted when a user swaps tokens.
    event TokensSwapped(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        address indexed tokenOut,
        uint256 amountOut
    );

    //===================================
    // 3. CUSTOM ERRORS
    //===================================

    /// @notice Reverts if one or both liquidity amounts are zero.
    error InvalidLiquidityAmounts(uint256 amountA, uint256 amountB);
    /// @notice Reverts if a token transfer fails.
    error TransferFailed(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    );
    /// @notice Reverts if requested amounts to remove exceed pool reserves.
    error InsufficientReserves(
        uint256 requestedA,
        uint256 requestedB,
        uint256 reserveA,
        uint256 reserveB
    );
    /// @notice Reverts if an action is attempted on an empty pool.
    error NoLiquidity();
    /// @notice Reverts if a swap is attempted with a zero amount.
    error InvalidSwapAmount(uint256 amountIn);
    /// @notice Reverts if an invalid token address is provided.
    error InvalidToken(address token);

    //===================================
    // 4. CONSTRUCTOR
    //===================================

    /// @notice Sets the two tokens for the exchange pool.
    constructor(IERC20 _tokenA, IERC20 _tokenB) Ownable(msg.sender) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    //===================================
    // 5. ADD LIQUIDITY
    //===================================

    /// @notice Allows the owner to add liquidity to the pool.
    function addLiquidity(uint256 amountA, uint256 amountB)
        external
        onlyOwner
        nonReentrant
    {
        // Checks
        if (amountA == 0 || amountB == 0) {
            revert InvalidLiquidityAmounts(amountA, amountB);
        }

        // Effects
        reserveA += amountA;
        reserveB += amountB;

        // Interactions
        if (!tokenA.transferFrom(msg.sender, address(this), amountA)) {
            revert TransferFailed(tokenA, msg.sender, address(this), amountA);
        }
        if (!tokenB.transferFrom(msg.sender, address(this), amountB)) {
            revert TransferFailed(tokenB, msg.sender, address(this), amountB);
        }

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    //===================================
    // 6. REMOVE LIQUIDITY
    //===================================

    /// @notice Allows the owner to remove liquidity from the pool.
    function removeLiquidity(uint256 amountA, uint256 amountB)
        external
        onlyOwner
        nonReentrant
    {
        // Checks
        if (reserveA < amountA || reserveB < amountB) {
            revert InsufficientReserves(amountA, amountB, reserveA, reserveB);
        }

        // Effects
        reserveA -= amountA;
        reserveB -= amountB;

        // Interactions
        if (!tokenA.transfer(msg.sender, amountA)) {
            revert TransferFailed(tokenA, address(this), msg.sender, amountA);
        }
        if (!tokenB.transfer(msg.sender, amountB)) {
            revert TransferFailed(tokenB, address(this), msg.sender, amountB);
        }

        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }

    //===================================
    // 7. SWAP A FOR B
    //===================================

    /// @notice Swaps a user's Token A for Token B from the pool.
    function swapAforB(uint256 amountAIn) external nonReentrant {
        // Checks
        if (amountAIn == 0) {
            revert InvalidSwapAmount(amountAIn);
        }
        if (reserveA == 0 || reserveB == 0) {
            revert NoLiquidity();
        }

        // Cache reserves to avoid re-reading from storage
        uint256 oldReserveA = reserveA;
        uint256 oldReserveB = reserveB;

        // Effects
        // Formula: (dx)amountOut = (reserve_out * amount_in) / (reserve_in + amount_in)
        uint256 amountBOut = (oldReserveB * amountAIn) / (oldReserveA + amountAIn);
        reserveA = oldReserveA + amountAIn;
        reserveB = oldReserveB - amountBOut;

        // Interactions
        if (!tokenA.transferFrom(msg.sender, address(this), amountAIn)) {
            revert TransferFailed(tokenA, msg.sender, address(this), amountAIn);
        }
        if (!tokenB.transfer(msg.sender, amountBOut)) {
            revert TransferFailed(
                tokenB,
                address(this),
                msg.sender,
                amountBOut
            );
        }

        emit TokensSwapped(
            msg.sender,
            address(tokenA),
            amountAIn,
            address(tokenB),
            amountBOut
        );

        // Invariant check: product should not decrease
        assert(reserveA * reserveB >= oldReserveA * oldReserveB);
    }

    //===================================
    // 8. SWAP B FOR A
    //===================================

    /// @notice Swaps a user's Token B for Token A from the pool.
    function swapBforA(uint256 amountBIn) external nonReentrant {
        // Checks
        if (amountBIn == 0) {
            revert InvalidSwapAmount(amountBIn);
        }
        if (reserveA == 0 || reserveB == 0) {
            revert NoLiquidity();
        }

        // Cache reserves
        uint256 oldReserveA = reserveA;
        uint256 oldReserveB = reserveB;

        // Effects
        // Formula: (dy)amountOut = (reserve_out * amount_in) / (reserve_in + amount_in)
        uint256 amountAOut = (oldReserveA * amountBIn) /
            (oldReserveB + amountBIn);
        reserveB = oldReserveB + amountBIn;
        reserveA = oldReserveA - amountAOut;

        // Interactions
        if (!tokenB.transferFrom(msg.sender, address(this), amountBIn)) {
            revert TransferFailed(tokenB, msg.sender, address(this), amountBIn);
        }
        if (!tokenA.transfer(msg.sender, amountAOut)) {
            revert TransferFailed(
                tokenA,
                address(this),
                msg.sender,
                amountAOut
            );
        }

        emit TokensSwapped(
            msg.sender,
            address(tokenB),
            amountBIn,
            address(tokenA),
            amountAOut
        );

        // Invariant check: product should not decrease
        assert(reserveA * reserveB >= oldReserveA * oldReserveB);
    }

    //===================================
    // 9. GET PRICE
    //===================================

    /// @notice Calculates the current spot price of one token in terms of the other.
    function getPrice(address _token) external view returns (uint256 price) {
        // Checks
        if (reserveA == 0 || reserveB == 0) {
            revert NoLiquidity();
        }

        // Price Logic
        if (_token == address(tokenA)) {
            // Price of A in B: reserveB / reserveA (scaled)
            price = (reserveB * 1e18) / reserveA;
        } else if (_token == address(tokenB)) {
            // Price of B in A: reserveA / reserveB (scaled)
            price = (reserveA * 1e18) / reserveB;
        } else {
            revert InvalidToken(_token);
        }

        assert(price > 0);
    }
}