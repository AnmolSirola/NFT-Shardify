// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Shardify is ERC20, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIdCounter;

    struct FractionalNFT {
        uint256 tokenId;
        address nftContract;
        address owner;
        uint256 totalShares;
        uint256 pricePerShare;
        uint256[] shareholders;
        bool active;
    }

    mapping(uint256 => FractionalNFT) public fractionalNFTs;

    constructor() ERC20("Shardify Token", "SHARD") {}

    function fractionalizeNFT(address nftContract, uint256 tokenId, uint256 initialShares, uint256 pricePerShare) external onlyOwner {
        require(nftContract != address(0), "Invalid contract");
        require(initialShares > 0, "Invalid shares");
        require(pricePerShare > 0, "Invalid price");

        // Verify NFT ownership
        address nftOwner = IERC721(nftContract).ownerOf(tokenId);
        require(nftOwner == owner(), "Not NFT owner");

        // Create a new fractional NFT
        FractionalNFT storage newFractionalNFT = fractionalNFTs[tokenIdCounter.current()];
        newFractionalNFT.tokenId = tokenId;
        newFractionalNFT.nftContract = nftContract;
        newFractionalNFT.owner = nftOwner;
        newFractionalNFT.totalShares = initialShares;
        newFractionalNFT.pricePerShare = pricePerShare;
        newFractionalNFT.shareholders.push(nftOwner);
        newFractionalNFT.active = true;

        // Mint fractional tokens to NFT owner
        _mint(nftOwner, initialShares);

        // Increment the tokenId counter
        tokenIdCounter.increment();
    }

    function buyShares(uint256 fractionalNFTId, uint256 shares) external payable {
        FractionalNFT storage fractionalNFT = fractionalNFTs[fractionalNFTId];
        require(fractionalNFT.active, "NFT not active");
        require(shares > 0, "Invalid shares");
        require(msg.value > 0, "Invalid payment");

        // Calculate total cost
        uint256 totalCost = fractionalNFT.pricePerShare * shares;
        require(msg.value >= totalCost, "Insufficient funds");

        // Transfer fractional tokens to buyer
        _transfer(fractionalNFT.owner, msg.sender, shares);

        // Update shareholders
        fractionalNFT.shareholders.push(msg.sender);

        // Send funds to NFT owner
        payable(fractionalNFT.owner).transfer(totalCost);

        // Emit event
        emit SharesBought(fractionalNFTId, msg.sender, shares, totalCost);
    }

    function redeemShares(uint256 fractionalNFTId, uint256 shares) external {
        FractionalNFT storage fractionalNFT = fractionalNFTs[fractionalNFTId];
        require(fractionalNFT.active, "NFT not active");
        require(shares > 0, "Invalid shares");

        // Transfer fractional tokens from redeemer to owner
        _transfer(msg.sender, fractionalNFT.owner, shares);

        // Update shareholders
        removeShareholder(fractionalNFT, msg.sender, shares);

        // Emit event
        emit SharesRedeemed(fractionalNFTId, msg.sender, shares);
    }

    function removeShareholder(FractionalNFT storage fractionalNFT, address shareholder, uint256 shares) internal {
        for (uint256 i = 0; i < fractionalNFT.shareholders.length; i++) {
            if (fractionalNFT.shareholders[i] == shareholder) {
                fractionalNFT.shareholders[i] = fractionalNFT.shareholders[fractionalNFT.shareholders.length - 1];
                fractionalNFT.shareholders.pop();
                break;
            }
        }
    }

    function deactivateNFT(uint256 fractionalNFTId) external onlyOwner {
        FractionalNFT storage fractionalNFT = fractionalNFTs[fractionalNFTId];
        require(fractionalNFT.active, "NFT not active");

        // Transfer remaining fractional tokens to NFT owner
        uint256 remainingShares = balanceOf(fractionalNFT.owner);
        _transfer(address(this), fractionalNFT.owner, remainingShares);

        // Deactivate NFT
        fractionalNFT.active = false;

        // Emit event
        emit NFTDeactivated(fractionalNFTId);
    }

    // Events
    event SharesBought(uint256 indexed fractionalNFTId, address buyer, uint256 shares, uint256 cost);
    event SharesRedeemed(uint256 indexed fractionalNFTId, address redeemer, uint256 shares);
    event NFTDeactivated(uint256 indexed fractionalNFTId);
}
