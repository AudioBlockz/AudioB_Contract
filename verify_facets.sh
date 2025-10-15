#!/bin/bash
# --------------------------------------------
# Verify all AudioBlocks facets on Lisk Sepolia
# --------------------------------------------

CHAIN_ID=4202
VERIFIER="blockscout"
VERIFIER_URL="https://sepolia-blockscout.lisk.com/api"
COMPILER_VERSION="0.8.28"

echo "Starting verification on Lisk Sepolia (chain ID: $CHAIN_ID)..."
echo ""

# ArtistFacet
forge verify-contract \
  0x31e322a43AceBcd6d557337775581e93E3873A5a \
  contracts/facets/ArtistFacet.sol:ArtistFacet \
  --chain $CHAIN_ID \
  --verifier $VERIFIER \
  --verifier-url $VERIFIER_URL \
  --compiler-version $COMPILER_VERSION

# SongFacet
forge verify-contract \
  0xaa06d4dF522d31F7718F135eA42b166C9002ea9B \
  contracts/facets/SongFacet.sol:SongFacet \
  --chain $CHAIN_ID \
  --verifier $VERIFIER \
  --verifier-url $VERIFIER_URL \
  --compiler-version $COMPILER_VERSION

# AlbumFacet
forge verify-contract \
  0x07D1f4D4ac6296155196306f225b4780258c4246 \
  contracts/facets/AlbumFacet.sol:AlbumFacet \
  --chain $CHAIN_ID \
  --verifier $VERIFIER \
  --verifier-url $VERIFIER_URL \
  --compiler-version $COMPILER_VERSION

# MarketPlaceFacet
forge verify-contract \
  0x3769931F368841485d3387596d0aB0f45c7CCd56 \
  contracts/facets/MarketPlaceFacet.sol:MarketPlaceFacet \
  --chain $CHAIN_ID \
  --verifier $VERIFIER \
  --verifier-url $VERIFIER_URL \
  --compiler-version $COMPILER_VERSION

# ERC721Facet
forge verify-contract \
  0xA189785f365D0E5b3110Fe749B154CC0Ec0054ef \
  contracts/facets/ERC721Facet.sol:ERC721Facet \
  --chain $CHAIN_ID \
  --verifier $VERIFIER \
  --verifier-url $VERIFIER_URL \
  --compiler-version $COMPILER_VERSION

# OwnershipControlFacet
forge verify-contract \
  0x1BeB8B55700FaAeBfdcf70A3AB3BB87f190D8578 \
  contracts/facets/OwnershipControlFacet.sol:OwnershipControlFacet \
  --chain $CHAIN_ID \
  --verifier $VERIFIER \
  --verifier-url $VERIFIER_URL \
  --compiler-version $COMPILER_VERSION

# HelperFacet
forge verify-contract \
  0x41002EFd81EeDEB75C0Fb95892ff22DCBa565bBD \
  contracts/facets/HelperFacet.sol:HelperFacet \
  --chain $CHAIN_ID \
  --verifier $VERIFIER \
  --verifier-url $VERIFIER_URL \
  --compiler-version $COMPILER_VERSION

# RoyaltySplitter
forge verify-contract \
  0xB6107e285cEd4D660c95d1053183180BeAaf0E2F \
  contracts/RoyaltySplitter.sol:RoyaltySplitter \
  --chain $CHAIN_ID \
  --verifier $VERIFIER \
  --verifier-url $VERIFIER_URL \
  --compiler-version $COMPILER_VERSION

echo ""
echo "✅ Verification commands sent for all facets!"
