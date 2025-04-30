#!/bin/bash

# CloudMart API Testing Script
# ----------------------------
# This script demonstrates how to interact with the CloudMart API
# It uses curl to make HTTP requests to the API endpoints

# Set the base URL (change this to your actual server address)
BASE_URL="http://localhost/api"

# Text colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}     CloudMart API Test Script    ${NC}"
echo -e "${BLUE}==================================${NC}"

# If a server address is provided as an argument, use it
if [ ! -z "$1" ]; then
  BASE_URL="http://$1/api"
  echo -e "${YELLOW}Using server: $1${NC}"
else
  echo -e "${YELLOW}Using default server: localhost${NC}"
fi

echo ""
echo -e "${GREEN}1. Getting all products${NC}"
echo -e "${YELLOW}curl -s $BASE_URL/products${NC}"
curl -s "$BASE_URL/products" | jq || echo "Error fetching products"
echo ""

echo -e "${GREEN}2. Getting a specific product (ID: 1)${NC}"
echo -e "${YELLOW}curl -s $BASE_URL/products/1${NC}"
curl -s "$BASE_URL/products/1" | jq || echo "Error fetching product"
echo ""

echo -e "${GREEN}3. Creating a new product${NC}"
echo -e "${YELLOW}curl -s -X POST $BASE_URL/products -H 'Content-Type: application/json' -d '{\"name\":\"Test Product\",\"price\":19.99,\"description\":\"A test product\",\"image\":\"https://via.placeholder.com/300x200?text=Test+Product\"}'${NC}"
NEW_PRODUCT=$(curl -s -X POST "$BASE_URL/products" \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","price":19.99,"description":"A test product","image":"https://via.placeholder.com/300x200?text=Test+Product"}')
echo "$NEW_PRODUCT" | jq || echo "Error creating product"
echo ""

# Extract the ID of the newly created product
NEW_ID=$(echo "$NEW_PRODUCT" | jq -r '.id')

if [ "$NEW_ID" != "null" ] && [ ! -z "$NEW_ID" ]; then
  echo -e "${GREEN}4. Updating the product (ID: $NEW_ID)${NC}"
  echo -e "${YELLOW}curl -s -X PUT $BASE_URL/products/$NEW_ID -H 'Content-Type: application/json' -d '{\"name\":\"Updated Product\",\"price\":29.99}'${NC}"
  curl -s -X PUT "$BASE_URL/products/$NEW_ID" \
    -H "Content-Type: application/json" \
    -d '{"name":"Updated Product","price":29.99}' | jq || echo "Error updating product"
  echo ""

  echo -e "${GREEN}5. Deleting the product (ID: $NEW_ID)${NC}"
  echo -e "${YELLOW}curl -s -X DELETE $BASE_URL/products/$NEW_ID${NC}"
  curl -s -X DELETE "$BASE_URL/products/$NEW_ID" | jq || echo "Error deleting product"
  echo ""
else
  echo -e "${RED}Could not get ID of new product, skipping update and delete tests${NC}"
fi

echo -e "${GREEN}6. Verifying all products again${NC}"
echo -e "${YELLOW}curl -s $BASE_URL/products${NC}"
curl -s "$BASE_URL/products" | jq || echo "Error fetching products"
echo ""

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}     API Testing Complete         ${NC}"
echo -e "${BLUE}==================================${NC}" 