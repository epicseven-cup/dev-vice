#!/usr/bin/env zsh
# digivice: test runner — runs every tests/*.test.zsh file with no external deps

DIR="${0:A:h}"
source "$DIR/test_helper.zsh"

typeset -a test_files
test_files=("$DIR"/*.test.zsh)

for f in "${test_files[@]}"; do
  echo "== ${f:t} =="
  run_tests_in_file "$f"
done

echo
echo "passed: $DIGIVICE_TEST_PASS, failed: $DIGIVICE_TEST_FAIL"

if (( DIGIVICE_TEST_FAIL > 0 )); then
  exit 1
fi
