// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {IUniswapV2Factory, Deployer} from "./util/Deployer.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {Helpers} from "./util/Helpers.sol";
import {Constants} from "./util/Constants.sol";
import {VmSafe} from "../lib/forge-std/src/Vm.sol";

contract UniswapV2PairTest is Test{
    IUniswapV2Factory factory;
    IUniswapV2Pair pair;
    IERC20 token0;
    IERC20 token1;
    address user;

    function setUp() public {
        factory = Deployer.deployFactory(address(this));
        address[] memory tokens = Deployer.deployTokens();
        token0 = IERC20(tokens[0]);
        token1 = IERC20(tokens[1]);
        address pairAddress = factory.createPair(address(token0), address(token1));
        pair = IUniswapV2Pair(pairAddress);
        user = address(this);

        // Mint initial tokens to user
        token0.mint(user, 1000 ether);
        token1.mint(user, 1000 ether);

        // Approve pair to transfer tokens
        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);
    }

    function test_mint() public {
        uint256 token0Amount = 1 ether;
        uint256 token1Amount = 4 ether;

        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);

        uint256 expectedLiquidity = 2 ether;
        uint256 minimumLiquidity = 1000;

        vm.expectEmit(true, true, true, true);
        emit IUniswapV2Pair.Transfer(address(0), address(0), minimumLiquidity);
        vm.expectEmit(true, true, true, true);
        emit IUniswapV2Pair.Transfer(address(0), user, expectedLiquidity - minimumLiquidity);
        vm.expectEmit(true, true, true, true);
        emit IUniswapV2Pair.Sync(token0Amount, token1Amount);
        vm.expectEmit(true, true, true, true);
        emit IUniswapV2Pair.Mint(user, token0Amount, token1Amount);

        pair.mint(user);

        assertEq(pair.totalSupply(), expectedLiquidity);
        assertEq(pair.balanceOf(user), expectedLiquidity - minimumLiquidity);
        assertEq(token0.balanceOf(address(pair)), token0Amount);
        assertEq(token1.balanceOf(address(pair)), token1Amount);

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, token0Amount);
        assertEq(reserve1, token1Amount);
    }

    function test_swap() public {
        uint256 token0Amount = 5 ether;
        uint256 token1Amount = 10 ether;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(user);

        uint256 swapAmount = 1 ether;
        uint256 expectedOutputAmount = 1662497915624478906;

        token0.transfer(address(pair), swapAmount);

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(pair), user, expectedOutputAmount);
        vm.expectEmit(true, true, true, true);
        emit IUniswapV2Pair.Sync(token0Amount + swapAmount, token1Amount - expectedOutputAmount);
        vm.expectEmit(true, true, true, true);
        emit IUniswapV2Pair.Swap(user, swapAmount, 0, 0, expectedOutputAmount, user);

        pair.swap(0, expectedOutputAmount, user, "0x");

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, token0Amount + swapAmount);
        assertEq(reserve1, token1Amount - expectedOutputAmount);
        assertEq(token0.balanceOf(address(pair)), token0Amount + swapAmount);
        assertEq(token1.balanceOf(address(pair)), token1Amount - expectedOutputAmount);
    }

    function test_burn() public {
        uint256 token0Amount = 3 ether;
        uint256 token1Amount = 3 ether;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(user);

        uint256 expectedLiquidity = 3 ether;
        uint256 minimumLiquidity = 1000;

        pair.transfer(address(pair), expectedLiquidity - minimumLiquidity);

        vm.expectEmit(true, true, true, true);
        emit IUniswapV2Pair.Transfer(address(pair), address(0), expectedLiquidity - minimumLiquidity);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(pair), user, token0Amount - 1000);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(pair), user, token1Amount - 1000);
        vm.expectEmit(true, true, true, true);
        emit IUniswapV2Pair.Sync(1000, 1000);
        vm.expectEmit(true, true, true, true);
        emit IUniswapV2Pair.Burn(user, token0Amount - 1000, token1Amount - 1000, user);

        pair.burn(user);

        assertEq(pair.balanceOf(user), 0);
        assertEq(pair.totalSupply(), minimumLiquidity);
        assertEq(token0.balanceOf(address(pair)), 1000);
        assertEq(token1.balanceOf(address(pair)), 1000);
    }

    function test_priceCumulativeLast() public {
        uint256 token0Amount = 3 ether;
        uint256 token1Amount = 3 ether;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(user);

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        vm.warp(blockTimestampLast + 1);
        pair.sync();

        (uint256 price0CumulativeLast, uint256 price1CumulativeLast) = pair.price0CumulativeLast();

        (uint256 expectedPrice0, uint256 expectedPrice1) = Helpers.encodePrice(token0Amount, token1Amount);

        assertEq(price0CumulativeLast, expectedPrice0);
        assertEq(price1CumulativeLast, expectedPrice1);

        ( , , blockTimestampLast) = pair.getReserves();
        assertEq(blockTimestampLast, blockTimestampLast + 1);

        uint256 swapAmount = 3 ether;
        token0.transfer(address(pair), swapAmount);
        vm.warp(blockTimestampLast + 10);
        pair.swap(0, 1 ether, user, "0x");

        (price0CumulativeLast, price1CumulativeLast) = pair.price0CumulativeLast();
        assertEq(price0CumulativeLast, expectedPrice0 * 10);
        assertEq(price1CumulativeLast, expectedPrice1 * 10);

        ( , , blockTimestampLast) = pair.getReserves();
        assertEq(blockTimestampLast, blockTimestampLast + 10);

        vm.warp(blockTimestampLast + 20);
        pair.sync();

        (expectedPrice0, expectedPrice1) = Helpers.encodePrice(6 ether, 2 ether);

        (price0CumulativeLast, price1CumulativeLast) = pair.price0CumulativeLast();

        assertEq(price0CumulativeLast, expectedPrice0 * 10 + (3 ether * 10));
        assertEq(price1CumulativeLast, expectedPrice1 * 10 + (3 ether * 10));

        ( , , blockTimestampLast) = pair.getReserves();
        assertEq(blockTimestampLast, blockTimestampLast + 20);
    }

    function test_feeTo_off() public {
        uint256 token0Amount = 1000 ether;
        uint256 token1Amount = 1000 ether;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(user);

        uint256 swapAmount = 1 ether;
        uint256 expectedOutputAmount = 996006981039903216;
        token1.transfer(address(pair), swapAmount);
        pair.swap(expectedOutputAmount, 0, user, "0x");

        uint256 expectedLiquidity = 1000 ether;
        uint256 minimumLiquidity = 1000;
        pair.transfer(address(pair), expectedLiquidity - minimumLiquidity);
        pair.burn(user);
        assertEq(pair.totalSupply(), minimumLiquidity);
    }

    function test_feeTo_on() public {
        vm.prank(address(factory));
        factory.setFeeTo(address(this));

        uint256 token0Amount = 1000 ether;
        uint256 token1Amount = 1000 ether;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(user);

        uint256 swapAmount = 1 ether;
        uint256 expectedOutputAmount = 996006981039903216;
        token1.transfer(address(pair), swapAmount);
        pair.swap(expectedOutputAmount, 0, user, "0x");

        uint256 expectedLiquidity = 1000 ether;
        uint256 minimumLiquidity = 1000;
        pair.transfer(address(pair), expectedLiquidity - minimumLiquidity);
        pair.burn(user);

        assertEq(pair.totalSupply(), minimumLiquidity + 249750499251388);
        assertEq(pair.balanceOf(address(this)), 249750499251388);
        assertEq(token0.balanceOf(address(pair)), 1000 + 249501683697445);
        assertEq(token1.balanceOf(address(pair)), 1000 + 250000187312969);
    }

    function test_skim() public {
        uint256 token0Amount = 1000 ether;
        uint256 token1Amount = 1000 ether;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(user);

        uint256 extraToken0 = 100 ether;
        uint256 extraToken1 = 200 ether;

        token0.transfer(address(pair), extraToken0);
        token1.transfer(address(pair), extraToken1);

        pair.skim(user);

        assertEq(token0.balanceOf(user), extraToken0);
        assertEq(token1.balanceOf(user), extraToken1);
        assertEq(token0.balanceOf(address(pair)), token0Amount);
        assertEq(token1.balanceOf(address(pair)), token1Amount);
    }

    function test_sync() public {
        uint256 token0Amount = 1000 ether;
        uint256 token1Amount = 1000 ether;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(user);

        token0.transfer(address(this), 100 ether);
        token1.transfer(address(this), 200 ether);

        pair.sync();

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, token0Amount);
        assertEq(reserve1, token1Amount);
    }
}