# dev-vice: minimal pure-zsh test helper (no external frameworks required)

typeset -g DEVVICE_TEST_PASS=0
typeset -g DEVVICE_TEST_FAIL=0
typeset -g DEVVICE_TEST_CURRENT=""

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [[ "$expected" == "$actual" ]]; then
    ((DEVVICE_TEST_PASS++))
  else
    ((DEVVICE_TEST_FAIL++))
    echo "  FAIL [$DEVVICE_TEST_CURRENT]${msg:+ $msg}: expected '$expected', got '$actual'" >&2
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if [[ "$haystack" == *"$needle"* ]]; then
    ((DEVVICE_TEST_PASS++))
  else
    ((DEVVICE_TEST_FAIL++))
    echo "  FAIL [$DEVVICE_TEST_CURRENT]${msg:+ $msg}: expected '$haystack' to contain '$needle'" >&2
  fi
}

assert_true() {
  local cond="$1" msg="${2:-}"
  if [[ "$cond" -eq 0 ]]; then
    ((DEVVICE_TEST_PASS++))
  else
    ((DEVVICE_TEST_FAIL++))
    echo "  FAIL [$DEVVICE_TEST_CURRENT]${msg:+ $msg}: expected success exit code, got $cond" >&2
  fi
}

assert_false() {
  local cond="$1" msg="${2:-}"
  if [[ "$cond" -ne 0 ]]; then
    ((DEVVICE_TEST_PASS++))
  else
    ((DEVVICE_TEST_FAIL++))
    echo "  FAIL [$DEVVICE_TEST_CURRENT]${msg:+ $msg}: expected non-zero exit code, got $cond" >&2
  fi
}

# runs every function matching test_* defined after sourcing the test file
run_tests_in_file() {
  local file="$1"
  local -a fns
  source "$file"
  fns=(${(ok)functions[(I)test_*]})
  local fn
  for fn in "${fns[@]}"; do
    DEVVICE_TEST_CURRENT="$fn"
    "$fn"
    unfunction "$fn"
  done
}
