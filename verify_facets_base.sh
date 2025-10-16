#!/bin/bash
# --------------------------------------------
# Verify all AudioBlocks facets on Base Sepolia
# --------------------------------------------

CHAIN_ID=84532
VERIFIER="etherscan"
VERIFIER_URL="https://sepolia-blockscout.lisk.com/api"
COMPILER_VERSION="0.8.28"

echo "Starting verification on Base Sepolia (chain ID: $CHAIN_ID)..."
echo ""




# ArtistFacet

  forge verify-contract 0x26d7009A6446BbD30eD93B4532BD04aCb8169325 ./contracts/facets/ArtistFacet.sol:ArtistFacet --chain $CHAIN_ID --watch

# SongFacet
  forge verify-contract 0xF71CFd08FDD394F4CE8703443A9dd31700884877 ./contracts/facets/SongFacet.sol:SongFacet --chain $CHAIN_ID --watch

  # AlbumFacet
  forge verify-contract 0x1BA66d7e1653582830e8B7B97c853Bce4Ce5AAa1 ./contracts/facets/AlbumFacet.sol:AlbumFacet --chain $CHAIN_ID --watch
  


# MarketPlaceFacet
forge verify-contract 0xf1036B59c205d7dB30D42e07831000B49135b948 ./contracts/facets/MarketPlaceFacet.sol:MarketPlaceFacet --chain $CHAIN_ID --watch

# ERC721Facet
forge verify-contract 0x81CAaa3956d3bCD9FEbC5af1e4CFe2fe5a9843fA ./contracts/facets/ERC721Facet.sol:ERC721Facet --chain $CHAIN_ID --watch

# OwnershipControlFacet
forge verify-contract 0x251d6791163431C8A089620869c4cAFdDA50A4d4 ./contracts/facets/OwnershipControlFacet.sol:OwnershipControlFacet --chain $CHAIN_ID --watch


# HelperFacet
forge verify-contract 0xA28690383b73dAC7510D8EC57c709889950f6C2c ./contracts/facets/HelperFacet.sol:HelperFacet --chain $CHAIN_ID --watch

# RoyaltySplitter
forge verify-contract 0x23b1BEd472f50b567ee4D5379C0aA719695805e8 ./contracts/facets/RoyaltySplitter.sol:RoyaltySplitter --chain $CHAIN_ID --watch


echo ""
echo "✅ Verification commands sent for all facets!"
