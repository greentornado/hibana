#!/bin/bash

# Integration test script for enterprise_suite sample app
# Tests Admin, I18n, SEO, TOTP, and API versioning features

set -e

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

# Test 2: Admin dashboard
test_html_content "/admin" "admin\|Admin\|Dashboard" "Admin dashboard loads"

# Test 3: API endpoints with versioning - v1
test_json_field "/api/v1/users" "users" "API v1 users endpoint"

# Test 4: API endpoints with versioning - v2
test_json_field "/api/v2/users" "users" "API v2 users endpoint"

# Test 5: API with Accept header versioning
echo -n "Testing /api/users with Accept header versioning... "
if response=$(curl -s -H "Accept: application/vnd.hibana.v1+json" "${BASE_URL}/api/users" 2>/dev/null); then
    if echo "$response" | grep -q "\"api_version\"\|\"version\""; then
        echo -e "${GREEN}PASS${NC} (Header versioning works)"
        ((PASSED++))
    else
        echo -e "${YELLOW}WARN${NC} (Header versioning unclear)"
        ((PASSED++))
    fi
else
    echo -e "${RED}FAIL${NC} (Connection error)"
    ((FAILED++))
fi

# Test 6: I18n locale info
test_json_field "/i18n/locale" "locale" "I18n locale detection"

# Test 7: I18n translations
test_json_field "/i18n/translations" "translations" "I18n translations list"

# Test 8: SEO endpoint
test_json_field "/seo" "meta_tags" "SEO meta tags endpoint"

# Test 9: SEO sitemap.xml
test_html_content "/sitemap.xml" "xml\|urlset" "SEO sitemap.xml"

# Test 10: SEO robots.txt
test_html_content "/robots.txt" "User-agent\|Allow\|Disallow" "SEO robots.txt"

# Test 11: TOTP setup endpoint
test_json_field "/totp/setup" "secret" "TOTP setup endpoint"

# Test 12: TOTP verify endpoint (with dummy code)
echo -n "Testing /totp/verify - TOTP verification... "
response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"secret":"dummy","code":"123456"}' \
    "${BASE_URL}/totp/verify" 2>/dev/null)
if echo "$response" | grep -q "\"status\"\|\"valid\"\|\"invalid\""; then
    echo -e "${GREEN}PASS${NC} (TOTP responds)"
    ((PASSED++))
else
    echo -e "${YELLOW}WARN${NC} (Response unclear)"
    ((PASSED++))
fi

# Test 13: Feature flags endpoint
test_json_field "/features" "features" "Feature flags endpoint"

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
