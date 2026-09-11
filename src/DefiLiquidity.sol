// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Repository:
// Commit:

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );
}

contract Submission {
    address private constant ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address private constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address private constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 private constant LOCKED = 1;
    uint256 private constant NOT_LOCKED = 2;

    uint256 private _status = NOT_LOCKED;

    modifier nonReentrant() {
        require(_status == NOT_LOCKED, "Reentrancy");
        _status = LOCKED;
        _;
        _status = NOT_LOCKED;
    }

    function swapUsdtForWeth(
        uint256 amountIn,
        uint256 amountOutMin,
        address recipient,
        uint256 deadline
    )
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Amount in is zero");
        require(recipient != address(0), "Invalid recipient");

        _safeTransferFrom(
            USDT,
            msg.sender,
            address(this),
            amountIn
        );

        _approveToken(
            USDT,
            ROUTER,
            amountIn
        );

        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = WETH;

        uint256[] memory amounts =
            IUniswapV2Router02(ROUTER).swapExactTokensForTokens(
                amountIn,
                amountOutMin,
                path,
                recipient,
                deadline
            );

        require(amounts.length >= 2, "Invalid router response");

        amountOut = amounts[amounts.length - 1];

        _approveToken(
            USDT,
            ROUTER,
            0
        );
    }

    function addUsdtWethLiquidity(
        uint256 usdtDesired,
        uint256 wethDesired,
        uint256 usdtMin,
        uint256 wethMin,
        address recipient,
        uint256 deadline
    )
        external
        nonReentrant
        returns (
            uint256 usdtUsed,
            uint256 wethUsed,
            uint256 liquidity
        )
    {
        require(usdtDesired > 0, "USDT amount is zero");
        require(wethDesired > 0, "WETH amount is zero");
        require(recipient != address(0), "Invalid recipient");

        _safeTransferFrom(
            USDT,
            msg.sender,
            address(this),
            usdtDesired
        );

        _safeTransferFrom(
            WETH,
            msg.sender,
            address(this),
            wethDesired
        );

        _approveToken(
            USDT,
            ROUTER,
            usdtDesired
        );

        _approveToken(
            WETH,
            ROUTER,
            wethDesired
        );

        (
            usdtUsed,
            wethUsed,
            liquidity
        ) = IUniswapV2Router02(ROUTER).addLiquidity(
            USDT,
            WETH,
            usdtDesired,
            wethDesired,
            usdtMin,
            wethMin,
            recipient,
            deadline
        );

        require(
            usdtUsed <= usdtDesired,
            "Invalid USDT used"
        );

        require(
            wethUsed <= wethDesired,
            "Invalid WETH used"
        );

        _approveToken(
            USDT,
            ROUTER,
            0
        );

        _approveToken(
            WETH,
            ROUTER,
            0
        );

        uint256 usdtRefund =
            usdtDesired - usdtUsed;

        uint256 wethRefund =
            wethDesired - wethUsed;

        if (usdtRefund > 0) {
            _safeTransfer(
                USDT,
                msg.sender,
                usdtRefund
            );
        }

        if (wethRefund > 0) {
            _safeTransfer(
                WETH,
                msg.sender,
                wethRefund
            );
        }
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    )
        internal
    {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                0x23b872dd,
                from,
                to,
                amount
            )
        );

        require(
            success &&
            (
                data.length == 0 ||
                (
                    data.length == 32 &&
                    abi.decode(data, (bool))
                )
            ),
            "Token transferFrom failed"
        );
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    )
        internal
    {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                0xa9059cbb,
                to,
                amount
            )
        );

        require(
            success &&
            (
                data.length == 0 ||
                (
                    data.length == 32 &&
                    abi.decode(data, (bool))
                )
            ),
            "Token transfer failed"
        );
    }

    function _approveToken(
        address token,
        address spender,
        uint256 amount
    )
        internal
    {
        (
            bool success,
            bytes memory data
        ) = token.call(
            abi.encodeWithSelector(
                0x095ea7b3,
                spender,
                0
            )
        );

        require(
            success &&
            (
                data.length == 0 ||
                (
                    data.length == 32 &&
                    abi.decode(data, (bool))
                )
            ),
            "Approval reset failed"
        );

        if (amount > 0) {
            (
                success,
                data
            ) = token.call(
                abi.encodeWithSelector(
                    0x095ea7b3,
                    spender,
                    amount
                )
            );

            require(
                success &&
                (
                    data.length == 0 ||
                    (
                        data.length == 32 &&
                        abi.decode(data, (bool))
                    )
                ),
                "Approval failed"
            );
        }
    }

    receive() external payable {}
}