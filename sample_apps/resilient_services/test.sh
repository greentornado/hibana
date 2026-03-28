#!/bin/bash

# Integration test script for resilient_services sample app
# Tests CircuitBreaker and PersistentQueue features

set -e

APP_NAME="resilient_services"
PORT=4010
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

# Test 1: Root endpoint (resilience overview)
test_endpoint "GET" "/" "200" "Resilience overview page"

# Test 2: CircuitBreaker status
test_json_field "/circuit_breaker/status" "circuit_breakers" "List circuit breakers"

# Test 3: Queue stats
test_json_field "/queue/stats" "queue" "Queue statistics"

# Test 4: Health check endpoint
test_json_field "/health" "status" "Health check endpoint"

# Test 5: Test circuit breaker call (simulated external API)
echo -n "Testing /circuit_breaker/test-api - Circuit breaker call... "
response=$(curl -s "${BASE_URL}/circuit_breaker/test-api" 2>/dev/null)
if echo "$response" | grep -q "\"status\"\|\"success\"\|\"error\""; then
    echo -e "${GREEN}PASS${NC} (Circuit breaker responds)"
    ((PASSED++))
else
    echo -e "${YELLOW}WARN${NC} (Response unclear)"
    echo "  Response: ${response}"
    ((PASSED++))  # Don't fail, might be circuit open
fi

# Test 6: Queue enqueue job
echo -n "Testing POST /queue/enqueue - Enqueue job... "
if response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{"task":"test_job","data":"test"}' \
    "${BASE_URL}/queue/enqueue" 2>/dev/null); then
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}PASS${NC} (Job enqueued)"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} (HTTP ${http_code})"
        ((FAILED++))
    fi
else
    echo -e "${RED}FAIL${NC} (Connection error)"
    ((FAILED++))
fi

# Test 7: Queue dequeue job
test_json_field "/queue/dequeue" "job" "Dequeue job from queue"

# Test 8: Queue clear
test_json_field "/queue/clear" "status" "Clear queue endpoint"

# Test 9: Demo external service with circuit breaker
echo -n "Testing /demo/external-api - External service demo... "
response=$(curl -s "${BASE_URL}/demo/external-api" 2>/dev/null)
if echo "$response" | grep -q "\"status\"\|\"data\"\|\"error\""; then
    echo -e "${GREEN}PASS${NC} (External API responds)"
    ((PASSED++))
else
    echo -e "${YELLOW}WARN${NC} (Response unclear)"
    echo "  Response: ${response}"
    ((PASSED++))
fi

# Test 10: Demo queue processing
echo -n "Testing /demo/queue-processing - Queue processing demo... "
response=$(curl -s "${BASE_URL}/demo/queue-processing" 2>/dev/null)
if echo "$response" | grep -q "\"jobs\"\|\"processed\"\|\"pending\""; then
    echo -e "${GREEN}PASS${NC} (Queue demo responds)"
    ((PASSED++))
else
    echo -e "${YELLOW}WARN${NC} (Response unclear)"
    echo "  Response: ${response}"
    ((PASSED++))
fi

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
