#!/usr/bin/env bash
# Fail if an ELF binary references a versioned glibc symbol newer than the
# floor this feedstock supports.
#
# Rust's std reaches for pidfd_spawnp/pidfd_getpid (GLIBC_2.39) on the process
# spawn path. They are *weak* references, so the program never calls them on an
# older kernel -- but the versioned dependency is recorded in .gnu.version_r
# regardless, and glibc's loader treats a missing version there as fatal. The
# binary therefore dies at exec with "version `GLIBC_2.39' not found" rather
# than falling back, which is why this has to be checked and not reasoned about.
set -euo pipefail

binary=${1:?usage: check-glibc-floor.sh <binary>}
# Debian bookworm ships 2.36 and Ubuntu jammy 2.35; both are in the install
# test matrix, so the floor has to clear the older of the two.
max_minor=${2:-34}

found=$(objdump -T "$binary" |
    grep -oE 'GLIBC_2\.[0-9]+' |
    sort -u -t. -k2 -n |
    awk -F. -v max="$max_minor" '$2 > max')

if [ -n "$found" ]; then
    echo "FAIL: $binary requires glibc newer than 2.$max_minor:" >&2
    printf '  %s\n' $found >&2
    echo "Symbols responsible:" >&2
    objdump -T "$binary" | grep -E "$(echo $found | tr ' ' '|')" >&2
    exit 1
fi

echo "OK: $binary needs nothing newer than GLIBC_2.$max_minor"
