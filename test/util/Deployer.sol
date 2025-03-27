// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vm} from "../../lib/forge-std/src/Test.sol";
import {IUniswapV2Factory} from "../../src/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2ERC20} from "../../src/interfaces/IUniswapV2ERC20.sol";

library Deployer {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function deployFactory(address _feeToSetter) internal returns (IUniswapV2Factory factory) {
        bytes memory args = abi.encode(_feeToSetter);
        bytes memory bytecode = abi.encodePacked(vm.getCode("UniswapV2Factory.sol:UniswapV2Factory"), args);
        assembly {
            factory := create(0, add(bytecode, 32), mload(bytecode))
        }
    }

    function deployERC20(uint256 mintAmount) internal returns (IUniswapV2ERC20 erc20) {
        bytes memory args = abi.encode(mintAmount);
        bytes memory bytecode = abi.encodePacked(vm.getCode("ERC20.sol:ERC20"), args);
        assembly {
            erc20 := create(0, add(bytecode, 32), mload(bytecode))
        }
    }

    function deployTokens() internal returns (address[] memory tokens) {
        IUniswapV2ERC20 token0 = deployERC20(1000000 ether);
        IUniswapV2ERC20 token1 = deployERC20(1000000 ether);
        tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
    }
}