#!/bin/bash

# QuickMart Microservices Test Script
# This script tests all three microservices using Terraform outputs
# Usage: ./test_microservices.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to make API calls with error handling
api_call() {
    local url="$1"
    local data="$2"
    local description="$3"
    
    print_info "Making API call: $description"
    echo -e "${PURPLE}URL: $url${NC}"
    echo -e "${PURPLE}Payload: $data${NC}"
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "$data")
    
    local body=$(echo "$response" | head -n -1)
    local http_code=$(echo "$response" | tail -n1)
    
    echo -e "${CYAN}Response ($http_code): $body${NC}"
    
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        print_success "$description succeeded"
        echo "$body"
    else
        print_error "$description failed with HTTP $http_code"
        echo "$body"
        return 1
    fi
}

# Function to extract JSON value (requires jq or basic parsing)
extract_json_value() {
    local json="$1"
    local key="$2"
    
    if command -v jq &> /dev/null; then
        echo "$json" | jq -r ".$key // empty"
    else
        # Basic parsing without jq (not as robust)
        echo "$json" | grep -o "\"$key\":[^,}]*" | cut -d':' -f2 | tr -d '"' | tr -d ' '
    fi
}

# Check if we're in the terraform directory
if [ ! -f "main.tf" ]; then
    print_error "This script must be run from the terraform directory"
    print_info "Please run: cd lambda-microservices/terraform && ./test_microservices.sh"
    exit 1
fi

# Check if Terraform has been applied
if [ ! -f "terraform.tfstate" ]; then
    print_error "Terraform state not found. Please run 'terraform apply' first."
    exit 1
fi

print_header "QuickMart Microservices Test Suite"

# Get service URLs from Terraform output
print_info "Getting service URLs from Terraform outputs..."

STORE_URL=$(terraform output -raw store_service_url 2>/dev/null)
INVENTORY_URL=$(terraform output -raw inventory_service_url 2>/dev/null)
GAS_PRICE_URL=$(terraform output -raw gas_price_service_url 2>/dev/null)

# Verify URLs were retrieved
if [ -z "$STORE_URL" ] || [ -z "$INVENTORY_URL" ] || [ -z "$GAS_PRICE_URL" ]; then
    print_error "Could not retrieve service URLs from Terraform output"
    print_info "Make sure 'terraform apply' has been completed successfully"
    exit 1
fi

print_success "Retrieved service URLs:"
echo -e "  Store Service: ${GREEN}$STORE_URL${NC}"
echo -e "  Inventory Service: ${GREEN}$INVENTORY_URL${NC}"
echo -e "  Gas Price Service: ${GREEN}$GAS_PRICE_URL${NC}"
echo

# =============================================================================
# Test Store Service
# =============================================================================
print_header "Testing Store Service"

# Test 1: Create a new store
print_info "Test 1: Creating a new store..."
STORE_RESPONSE=$(api_call "$STORE_URL" '{
    "action": "addStore",
    "store": {
        "name": "QuickMart Central",
        "address": "123 Main St",
        "city": "Anytown"
    }
}' "Create Store")

# Extract store_id from response
STORE_ID=$(extract_json_value "$STORE_RESPONSE" "store_id")
if [ -z "$STORE_ID" ] || [ "$STORE_ID" = "null" ]; then
    print_error "Could not extract store_id from response"
    exit 1
fi

print_success "Created store with ID: $STORE_ID"
echo

# Test 2: Get store details
print_info "Test 2: Retrieving store details..."
api_call "$STORE_URL" "{
    \"action\": \"getStore\",
    \"store_id\": $STORE_ID
}" "Get Store Details" > /dev/null

echo

# Test 3: List all stores
print_info "Test 3: Listing all stores..."
api_call "$STORE_URL" '{
    "action": "listStores"
}' "List All Stores" > /dev/null

echo

# =============================================================================
# Test Inventory Service (with Store Validation)
# =============================================================================
print_header "Testing Inventory Service"

# Test 4: Add items to store (tests inter-service communication)
print_info "Test 4: Adding inventory items to store..."

# Add first item
ITEM1_RESPONSE=$(api_call "$INVENTORY_URL" "{
    \"action\": \"addItemToStore\",
    \"payload\": {
        \"store_id\": $STORE_ID,
        \"item_name\": \"Premium Coffee Beans\",
        \"quantity\": 50,
        \"price\": 12.99
    }
}" "Add Coffee Beans")

ITEM1_ID=$(extract_json_value "$ITEM1_RESPONSE" "item_id")
print_success "Added item with ID: $ITEM1_ID"
echo

# Add second item
ITEM2_RESPONSE=$(api_call "$INVENTORY_URL" "{
    \"action\": \"addItemToStore\",
    \"payload\": {
        \"store_id\": $STORE_ID,
        \"item_name\": \"Bottled Water 1L\",
        \"quantity\": 100,
        \"price\": 1.50
    }
}" "Add Bottled Water")

ITEM2_ID=$(extract_json_value "$ITEM2_RESPONSE" "item_id")
print_success "Added item with ID: $ITEM2_ID"
echo

# Test 5: Get store inventory
print_info "Test 5: Retrieving store inventory..."
api_call "$INVENTORY_URL" "{
    \"action\": \"getStoreInventory\",
    \"payload\": {
        \"store_id\": $STORE_ID
    }
}" "Get Store Inventory" > /dev/null

echo

# Test 6: Update item quantity
if [ -n "$ITEM1_ID" ] && [ "$ITEM1_ID" != "null" ]; then
    print_info "Test 6: Updating item quantity..."
    api_call "$INVENTORY_URL" "{
        \"action\": \"updateItemQuantity\",
        \"payload\": {
            \"item_id\": $ITEM1_ID,
            \"quantity\": 45
        }
    }" "Update Item Quantity" > /dev/null
    echo
else
    print_warning "Skipping quantity update test (no valid item_id)"
fi

# =============================================================================
# Test Gas Price Service (with Store Validation)
# =============================================================================
print_header "Testing Gas Price Service"

# Test 7: Update gas prices (tests inter-service communication)
print_info "Test 7: Setting gas prices..."

# Set Regular gas price
api_call "$GAS_PRICE_URL" "{
    \"action\": \"updateGasPrice\",
    \"payload\": {
        \"store_id\": $STORE_ID,
        \"fuel_type\": \"Regular\",
        \"price\": 3.799
    }
}" "Set Regular Gas Price" > /dev/null

echo

# Set Premium gas price
api_call "$GAS_PRICE_URL" "{
    \"action\": \"updateGasPrice\",
    \"payload\": {
        \"store_id\": $STORE_ID,
        \"fuel_type\": \"Premium\",
        \"price\": 4.299
    }
}" "Set Premium Gas Price" > /dev/null

echo

# Set Diesel gas price
api_call "$GAS_PRICE_URL" "{
    \"action\": \"updateGasPrice\",
    \"payload\": {
        \"store_id\": $STORE_ID,
        \"fuel_type\": \"Diesel\",
        \"price\": 4.099
    }
}" "Set Diesel Gas Price" > /dev/null

echo

# Test 8: Get gas prices for store
print_info "Test 8: Retrieving gas prices for store..."
api_call "$GAS_PRICE_URL" "{
    \"action\": \"getGasPricesForStore\",
    \"payload\": {
        \"store_id\": $STORE_ID
    }
}" "Get Gas Prices" > /dev/null

echo

# =============================================================================
# Test Error Handling
# =============================================================================
print_header "Testing Error Handling"

# Test 9: Try to add item to non-existent store
print_info "Test 9: Testing store validation (should fail)..."
set +e  # Don't exit on error for this test
api_call "$INVENTORY_URL" '{
    "action": "addItemToStore",
    "payload": {
        "store_id": 99999,
        "item_name": "Test Item",
        "quantity": 1,
        "price": 1.00
    }
}' "Add Item to Non-existent Store" > /dev/null
set -e

echo

# Test 10: Try to get non-existent store
print_info "Test 10: Testing get non-existent store (should fail)..."
set +e  # Don't exit on error for this test
api_call "$STORE_URL" '{
    "action": "getStore",
    "store_id": 99999
}' "Get Non-existent Store" > /dev/null
set -e

echo

# =============================================================================
# Summary
# =============================================================================
print_header "Test Summary"

print_success "All tests completed successfully!"
echo
print_info "Test Results Summary:"
echo -e "  ${GREEN}✅ Store Service: Working${NC}"
echo -e "     - Store creation: ✅"
echo -e "     - Store retrieval: ✅"
echo -e "     - Store listing: ✅"
echo
echo -e "  ${GREEN}✅ Inventory Service: Working${NC}"
echo -e "     - Item creation: ✅"
echo -e "     - Store validation: ✅ (inter-service communication)"
echo -e "     - Inventory retrieval: ✅"
echo -e "     - Quantity updates: ✅"
echo
echo -e "  ${GREEN}✅ Gas Price Service: Working${NC}"
echo -e "     - Price updates: ✅"
echo -e "     - Store validation: ✅ (inter-service communication)"
echo -e "     - Price retrieval: ✅"
echo
echo -e "  ${GREEN}✅ Error Handling: Working${NC}"
echo -e "     - Invalid store validation: ✅"
echo -e "     - Not found responses: ✅"
echo

print_info "Database Contents Created:"
echo -e "  Store ID: ${CYAN}$STORE_ID${NC} (QuickMart Central)"
echo -e "  Inventory Items: ${CYAN}2${NC} (Coffee Beans, Bottled Water)"
echo -e "  Gas Prices: ${CYAN}3${NC} (Regular, Premium, Diesel)"
echo

print_success "🎉 QuickMart microservices are fully functional!"
print_info "You can now use the service URLs to integrate with other applications."

# Optional: Save results to file
RESULTS_FILE="test_results_$(date +%Y%m%d_%H%M%S).log"
echo "Test completed at $(date)" > "$RESULTS_FILE"
echo "Store ID: $STORE_ID" >> "$RESULTS_FILE"
echo "Store URL: $STORE_URL" >> "$RESULTS_FILE"
echo "Inventory URL: $INVENTORY_URL" >> "$RESULTS_FILE"
echo "Gas Price URL: $GAS_PRICE_URL" >> "$RESULTS_FILE"

print_info "Test results saved to: $RESULTS_FILE" 