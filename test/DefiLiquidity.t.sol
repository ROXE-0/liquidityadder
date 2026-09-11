// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Submission} from "../src/Submission.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

interface IRouter {
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

contract SubmissionTest is Test {
    address constant ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address constant PAIR =
        0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;

    uint256 constant FORK_BLOCK = 25_949_200;

    // 6 decimals
    uint256 constant USDT_SWAP_AMOUNT = 10e6;

    // Used for liquidity test
    uint256 constant USDT_LIQUIDITY_AMOUNT = 100e6;
    uint256 constant WETH_LIQUIDITY_AMOUNT = 0.05 ether;

    address holder;
    address user;
    address recipient;

    Submission submission;

    function setUp() public {
        vm.createSelectFork(
            vm.envString("MAINNET_RPC_URL"),
            FORK_BLOCK
        );

        holder = vm.envAddress("FUNDED_HOLDER");

        user = makeAddr("user");
        recipient = makeAddr("recipient");

        submission = new Submission();

        require(
            IERC20(USDT).balanceOf(holder) >=
                USDT_SWAP_AMOUNT + USDT_LIQUIDITY_AMOUNT,
            "Holder lacks USDT"
        );

        require(
            IERC20(WETH).balanceOf(holder) >=
                WETH_LIQUIDITY_AMOUNT,
            "Holder lacks WETH"
        );
    }

    function testSwapUsdtForWeth() public {
        // Fund fresh test user from the real mainnet holder.
        vm.prank(holder);
        _rawTransfer(
            USDT,
            user,
            USDT_SWAP_AMOUNT
        );

        // User approves Submission.
        vm.prank(user);
        _safeApprove(
            USDT,
            address(submission),
            USDT_SWAP_AMOUNT
        );

        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = WETH;

        uint256[] memory quote =
            IRouter(ROUTER).getAmountsOut(
                USDT_SWAP_AMOUNT,
                path
            );

        // Accept a 5% slippage tolerance.
        uint256 amountOutMin =
            (quote[1] * 95) / 100;

        uint256 recipientBefore =
            IERC20(WETH).balanceOf(recipient);

        vm.prank(user);
        uint256 amountOut =
            submission.swapUsdtForWeth(
                USDT_SWAP_AMOUNT,
                amountOutMin,
                recipient,
                block.timestamp + 1 hours
            );

        uint256 recipientAfter =
            IERC20(WETH).balanceOf(recipient);

        assertGt(
            amountOut,
            0,
            "Swap returned zero WETH"
        );

        assertGt(
            recipientAfter,
            recipientBefore,
            "Recipient WETH balance did not increase"
        );
    }

    function testAddUsdtWethLiquidity() public {
        // Fund fresh test user from the real mainnet holder.
        vm.startPrank(holder);

        _rawTransfer(
            USDT,
            user,
            USDT_LIQUIDITY_AMOUNT
        );

        _rawTransfer(
            WETH,
            user,
            WETH_LIQUIDITY_AMOUNT
        );

        vm.stopPrank();

        // User approves Submission for both tokens.
        vm.startPrank(user);

        _safeApprove(
            USDT,
            address(submission),
            USDT_LIQUIDITY_AMOUNT
        );

        _safeApprove(
            WETH,
            address(submission),
            WETH_LIQUIDITY_AMOUNT
        );

        vm.stopPrank();

        uint256 lpBefore =
            IERC20(PAIR).balanceOf(user);

        vm.prank(user);

        (
            uint256 usdtUsed,
            uint256 wethUsed,
            uint256 liquidity
        ) = submission.addUsdtWethLiquidity(
            USDT_LIQUIDITY_AMOUNT,
            WETH_LIQUIDITY_AMOUNT,
            0,
            0,
            user,
            block.timestamp + 1 hours
        );

        uint256 lpAfter =
            IERC20(PAIR).balanceOf(user);

        assertGt(
            usdtUsed,
            0,
            "No USDT used"
        );

        assertGt(
            wethUsed,
            0,
            "No WETH used"
        );

        assertGt(
            liquidity,
            0,
            "No LP tokens minted"
        );

        assertGt(
            lpAfter,
            lpBefore,
            "LP balance did not increase"
        );
    }

    function _rawTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) =
            token.call(
                abi.encodeWithSelector(
                    bytes4(keccak256("transfer(address,uint256)")),
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

    function _safeApprove(
        address token,
        address spender,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) =
            token.call(
                abi.encodeWithSelector(
                    bytes4(keccak256("approve(address,uint256)")),
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
            "Token approval failed"
        );
    }
}