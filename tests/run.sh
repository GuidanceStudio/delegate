#!/usr/bin/env bash
# Runs every test_* function in tests/test_*.sh, each in a fresh setup.
cd "$(dirname "$0")"
pass=0 failed=0
for file in test_*.sh; do
    for t in $(bash -c "source ./$file; declare -F" | awk '{print $3}' | grep '^test_'); do
        if bash -c "source ./lib.sh; source ./$file; setup; $t; rc=\$?; teardown; exit \$rc"; then
            pass=$((pass + 1))
        else
            echo "FAIL $file::$t"; failed=$((failed + 1))
        fi
    done
done
echo "$pass passed, $failed failed"
[ "$failed" -eq 0 ]
