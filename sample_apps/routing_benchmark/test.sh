#!/bin/bash

# Integration test script for routing_benchmark sample app
# Tests O(1) CompiledRouter performance demo

APP_NAME="routing_benchmark"
PORT=4007
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

# Function to test latency
test_latency() {
    local endpoint=$1
    local max_ms=$2
    local description=$3
    
    echo -n "Testing ${endpoint} latency < ${max_ms}ms - ${description}... "
    
    start_time=$(date +%s%N)
    response=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${endpoint}" 2>/dev/null)
    end_time=$(date +%s%N)
    
    duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    
    if [ "$response" = "200" ] && [ "$duration" -lt "$max_ms" ]; then
        echo -e "${GREEN}PASS${NC} (${duration}ms)"
        ((PASSED++))
    elif [ "$response" != "200" ]; then
        echo -e "${RED}FAIL${NC} (HTTP ${response})"
        ((FAILED++))
    else
        echo -e "${YELLOW}SLOW${NC} (${duration}ms, expected < ${max_ms}ms)"
        ((PASSED++))
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

# Test 1: Root endpoint
test_endpoint "GET" "/" "200" "Root endpoint returns info"

# Test 2: Routes list endpoint  
test_endpoint "GET" "/routes" "200" "List all compiled routes"

# Test 3: Benchmark endpoint
test_endpoint "GET" "/benchmark" "200" "Run benchmark"

# Test 4: Performance test endpoint
test_endpoint "GET" "/perf/1" "200" "Performance test route"

# Test 5: Compare endpoint
test_endpoint "GET" "/compare" "200" "Compare routing approaches"

# Test 6: Test static route (1-500)
test_endpoint "GET" "/static/123" "200" "Static route /static/123"

# Test 7: Test user route (1-300)
test_endpoint "GET" "/user/42" "200" "User route /user/42"

# Test 8: Test API route (v1-v2, 1-50)
test_endpoint "GET" "/api/v1/item/25" "200" "API route /api/v1/item/25"

# Test 9: Test file route
test_endpoint "GET" "/files/docs/5" "200" "File route /files/docs/5"

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
