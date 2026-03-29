#!/bin/bash

# Integration test script for enterprise_suite sample app
# Tests basic routing and parameter handling

APP_NAME="enterprise_suite"
PORT=4011
BASE_URL="http://localhost:${PORT}"
FAILED=0
PASSED=0

echo "===================================="
echo "Testing ${APP_NAME} (port ${PORT})"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local expected_status=$3
    local description=$4
    
    echo -n "Testing ${method} ${endpoint} - ${description}... "
    
    if response=$(curl -s -w "\n%{http_code}" -X "${method}" "${BASE_URL}${endpoint}" 2>/dev/null); then
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')
        
        if [ "$http_code" = "$expected_status" ]; then
            echo -e "${GREEN}PASS${NC} (HTTP ${http_code})"
            ((PASSED++))
        else
            echo -e "${RED}FAIL${NC} (Expected ${expected_status}, got ${http_code})"
            echo "  Response: ${body}"
            ((FAILED++))
        fi
    else
        echo -e "${RED}FAIL${NC} (Connection error)"
        ((FAILED++))
    fi
}

# Function to test HTML content
test_html_content() {
    local endpoint=$1
    local pattern=$2
    local description=$3
    
    echo -n "Testing ${endpoint} - ${description}... "
    
    if response=$(curl -s "${BASE_URL}${endpoint}" 2>/dev/null); then
        if echo "$response" | grep -qi "$pattern"; then
            echo -e "${GREEN}PASS${NC} (Pattern '${pattern}' found)"
            ((PASSED++))
        else
            echo -e "${RED}FAIL${NC} (Pattern '${pattern}' not found)"
            ((FAILED++))
        fi
    else
        echo -e "${RED}FAIL${NC} (Connection error)"
        ((FAILED++))
    fi
}

# Function to test JSON response contains field
test_json_field() {
    local endpoint=$1
    local field=$2
    local description=$3
    
    echo -n "Testing ${endpoint} - ${description}... "
    
    if response=$(curl -s "${BASE_URL}${endpoint}" 2>/dev/null); then
        if echo "$response" | grep -q "\"${field}\""; then
            echo -e "${GREEN}PASS${NC} (Field '${field}' found)"
            ((PASSED++))
        else
            echo -e "${RED}FAIL${NC} (Field '${field}' not found)"
            echo "  Response: ${response}"
            ((FAILED++))
        fi
    else
        echo -e "${RED}FAIL${NC} (Connection error)"
        ((FAILED++))
    fi
}

# Start the server
echo "Starting ${APP_NAME} server..."
cd "$(dirname "$0")"

# Check if already running
if curl -s "${BASE_URL}/" > /dev/null 2>&1; then
    echo "Server already running on port ${PORT}"
else
    # Start server in background
    mix run --no-halt > /tmp/${APP_NAME}_server.log 2>&1 &
    SERVER_PID=$!
    
    # Wait for server to be ready
    echo "Waiting for server to start..."
    for i in {1..30}; do
        if curl -s "${BASE_URL}/" > /dev/null 2>&1; then
            echo "Server started successfully"
            break
        fi
        sleep 1
        if [ $i -eq 30 ]; then
            echo -e "${RED}ERROR: Server failed to start${NC}"
            cat /tmp/${APP_NAME}_server.log
            exit 1
        fi
    done
fi

echo ""
echo "Running tests..."
echo ""

# Test 1: Root endpoint (enterprise overview)
test_endpoint "GET" "/" "200" "Enterprise overview page"

# Test 2: Hello with name parameter (HTML)
test_html_content "/hello/World" "World" "Hello endpoint with name parameter"

# Test 3: Hello with JSON response
test_json_field "/hello/Elixir" "name" "Hello endpoint returns JSON with name field"

echo ""
echo "===================================="
echo "Results:"
echo -e "  ${GREEN}Passed: ${PASSED}${NC}"
echo -e "  ${RED}Failed: ${FAILED}${NC}"
echo "===================================="

# Cleanup
if [ ! -z "$SERVER_PID" ]; then
    echo "Stopping server..."
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
fi

# Exit with appropriate code
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
