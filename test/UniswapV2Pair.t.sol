// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;
import "../lib/forge-std/src/Test.sol";
import "../src/Contracts/UniswapV2Pair.sol";
import {Test, console} from "../lib/forge-std/src/Test.sol";
import {IUniswapV2ERC20,IUniswapV2Factory,Deployer} from "./util/Deployer.sol";
import "../src/interfaces/IUniswapV2Pair.sol";
import {Helpers} from "./util/Helpers.sol";
import {Constants} from "./util/Constants.sol";


abstract contract Deployed is Test {
    IUniswapV2Factory factory;
    IUniswapV2Pair pair;
    IUniswapV2ERC20 token0;
    IUniswapV2ERC20 token1;
    address user;

    function setUp() public virtual {
        factory = Deployer.deployFactory(address(this));
         user = address(this);
         token0 = Deployer.deployERC20(1000000 ether);
         token1 = Deployer.deployERC20(1000000 ether);
        address pairAddress = factory.createPair(address(token0), address(token1));
        pair = IUniswapV2Pair(pairAddress);
        

        // Mint initial tokens to user
        token0.transfer(user, 1000 ether);
        token1.transfer(user, 1000 ether);

        // Approve pair to transfer tokens
        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);
    }

}
contract UniswapV2PairTest is Deployed{

    function test_mint() public {
        uint112 token0Amount = 1 ether;
        uint112 token1Amount = 4 ether;

        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);

        uint112 expectedLiquidity = 2 ether;
        uint112 minimumLiquidity = 1000;

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
        uint112 token0Amount = 5 ether;
        uint112 token1Amount = 10 ether;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(user);

        uint112 swapAmount = 1 ether;
        uint112 expectedOutputAmount = 1662497915624478906;

        token0.transfer(address(pair), swapAmount);

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
        emit IUniswapV2ERC20.Transfer(address(pair), user, token0Amount - 1000);
        vm.expectEmit(true, true, true, true);
        emit IUniswapV2ERC20.Transfer(address(pair), user, token1Amount - 1000);
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

    uint256 price0CumulativeLast = pair.price0CumulativeLast();
    uint256 price1CumulativeLast = pair.price1CumulativeLast();

    // Calculate expected price directly
    uint256 expectedPrice0 = (token0Amount * 2**112) / token1Amount;
    uint256 expectedPrice1 = (token1Amount * 2**112) / token0Amount;

    assertEq(price0CumulativeLast, expectedPrice0);
    assertEq(price1CumulativeLast, expectedPrice1);

    ( , , blockTimestampLast) = pair.getReserves();
    assertEq(blockTimestampLast, blockTimestampLast);

    }

    function test_feeTo_off() public {
vm.prank(address(factory));
        vm.expectRevert("UniswapV2: FORBIDDEN");
        factory.setFeeTo(address(0));
    }

    function test_feeTo_on() public {
        
        vm.prank(address(factory));
        vm.expectRevert("UniswapV2: FORBIDDEN");
        factory.setFeeToSetter(address(this));
        factory.setFeeTo(address(this));
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

        assertEq(token0.balanceOf(user), 999000000000000000000000);
        assertEq(token1.balanceOf(user), 999000000000000000000000);
        assertEq(token0.balanceOf(address(pair)), 1000 ether);
        assertEq(token1.balanceOf(address(pair)), 1000 ether);
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