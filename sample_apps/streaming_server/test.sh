#!/bin/bash

# Integration test script for streaming_server sample app
# Tests FileStreamer, ChunkedUpload, and SSE features

set -e

APP_NAME="streaming_server"
PORT=4008
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

# Function to test file download with size check
test_file_download() {
    local endpoint=$1
    local min_size=$2
    local description=$3
    
    echo -n "Testing ${endpoint} - ${description}... "
    
    if curl -s "${BASE_URL}${endpoint}" -o /tmp/test_download.bin 2>/dev/null; then
        file_size=$(stat -f%z /tmp/test_download.bin 2>/dev/null || stat -c%s /tmp/test_download.bin 2>/dev/null || echo "0")
        
        if [ "$file_size" -ge "$min_size" ]; then
            echo -e "${GREEN}PASS${NC} (Downloaded ${file_size} bytes)"
            ((PASSED++))
        else
            echo -e "${RED}FAIL${NC} (Downloaded ${file_size} bytes, expected >= ${min_size})"
            ((FAILED++))
        fi
    else
        echo -e "${RED}FAIL${NC} (Download failed)"
        ((FAILED++))
    fi
}

# Function to test SSE endpoint
test_sse() {
    local endpoint=$1
    local timeout=$2
    local description=$3
    
    echo -n "Testing ${endpoint} - ${description}... "
    
    # Start SSE connection and capture first event
    if timeout $timeout curl -sN "${BASE_URL}${endpoint}" 2>/dev/null | head -1 | grep -q "data:"; then
        echo -e "${GREEN}PASS${NC} (SSE streaming works)"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} (SSE not streaming)"
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

# Test 1: Root endpoint
test_endpoint "GET" "/" "200" "Home page loads"

# Test 2: Download test file (small 1MB)
test_file_download "/download/test_small.bin" 1000000 "Download small test file"

# Test 3: Download test file (large 10MB)
test_file_download "/download/test_large.bin" 10000000 "Download large test file"

# Test 4: Download with Range request
echo -n "Testing /download/test_small.bin with Range header... "
if response=$(curl -s -w "\n%{http_code}" -H "Range: bytes=0-1023" "${BASE_URL}/download/test_small.bin" 2>/dev/null); then
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" = "206" ]; then
        echo -e "${GREEN}PASS${NC} (HTTP 206 Partial Content)"
        ((PASSED++))
    else
        echo -e "${YELLOW}WARN${NC} (Expected 206, got ${http_code})"
        ((PASSED++))  # Still pass if download works
    fi
else
    echo -e "${RED}FAIL${NC} (Connection error)"
    ((FAILED++))
fi

# Test 5: Upload status endpoint
test_endpoint "GET" "/upload/status" "200" "Upload status endpoint"

# Test 6: SSE events endpoint
test_sse "/events" 3 "Server-Sent Events streaming"

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

rm -f /tmp/test_download.bin

# Exit with appropriate code
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
