#!/bin/bash

# Master test runner for all sample apps
# Run individual test scripts or all tests

# set -e  # Disabled to continue testing other apps even if one fails

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0
PASSED=0
SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# List of sample apps with test scripts
APPS_WITH_TESTS=(
    "routing_benchmark"
    "streaming_server"
    "realtime_cluster"
    "resilient_services"
    "enterprise_suite"
)

# Show usage
usage() {
    echo "Usage: $0 [options] [app_name]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -l, --list      List all sample apps with tests"
    echo "  -a, --all       Run tests for all sample apps (default)"
    echo ""
    echo "Arguments:"
    echo "  app_name        Run tests for specific app"
    echo ""
    echo "Available apps:"
    for app in "${APPS_WITH_TESTS[@]}"; do
        echo "  - ${app}"
    done
    echo ""
    echo "Examples:"
    echo "  $0                      # Run all tests"
    echo "  $0 routing_benchmark      # Test only routing_benchmark"
    echo "  $0 --list               # List available apps"
    exit 0
}

# List available apps
list_apps() {
    echo "Sample apps with test scripts:"
    echo ""
    for app in "${APPS_WITH_TESTS[@]}"; do
        test_script="${SCRIPT_DIR}/${app}/test.sh"
        if [ -f "$test_script" ]; then
            echo -e "  ${GREEN}✓${NC} ${app}"
        else
            echo -e "  ${RED}✗${NC} ${app} (no test.sh)"
        fi
    done
    echo ""
    echo "Other sample apps (no tests yet):"
    for dir in "${SCRIPT_DIR}"/*/; do
        app=$(basename "$dir")
        if [[ ! " ${APPS_WITH_TESTS[@]} " =~ " ${app} " ]] && [ -f "${dir}/mix.exs" ]; then
            echo -e "  ${YELLOW}-${NC} ${app}"
        fi
    done
    exit 0
}

# Run test for a single app
run_test() {
    local app=$1
    local test_script="${SCRIPT_DIR}/${app}/test.sh"
    
    if [ ! -f "$test_script" ]; then
        echo -e "${RED}ERROR: No test script found for ${app}${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Testing: ${app}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if bash "$test_script"; then
        ((PASSED++))
    else
        ((FAILED++))
        echo -e "${RED}✗ ${app} tests failed${NC}"
    fi
}

# Main logic
main() {
    # Parse arguments
    if [ $# -eq 0 ]; then
        # Run all tests
        echo "Running tests for all sample apps..."
        for app in "${APPS_WITH_TESTS[@]}"; do
            run_test "$app"
        done
    elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
    elif [ "$1" = "-l" ] || [ "$1" = "--list" ]; then
        list_apps
    elif [ "$1" = "-a" ] || [ "$1" = "--all" ]; then
        # Run all tests
        echo "Running tests for all sample apps..."
        for app in "${APPS_WITH_TESTS[@]}"; do
            run_test "$app"
        done
    else
        # Run specific app test
        app=$1
        if [[ " ${APPS_WITH_TESTS[@]} " =~ " ${app} " ]]; then
            run_test "$app"
        else
            echo -e "${RED}ERROR: Unknown app '${app}'${NC}"
            echo "Run '$0 --list' to see available apps"
            exit 1
        fi
    fi
    
    # Summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  TEST SUMMARY${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}✓ Passed: ${PASSED}${NC}"
    echo -e "  ${RED}✗ Failed: ${FAILED}${NC}"
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

main "$@"
