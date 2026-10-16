#!/usr/bin/env bash
# Fetch the header sets the committed bindings are generated from, into
# <dir>/<triple>/{glibc,kernel}/include, and print the regenerate.sh
# invocation for each target.
#
# These are the glibc 2.28 and Linux 4.19 UAPI header packages published by
# github.com/cerisier (the same artifacts Bazel's `llvm` toolchain module uses),
# pinned by SHA-256 so every host regenerates identical bytes.
set -euo pipefail

dir=${1:?destination directory}

fetch() { # <url> <sha256> <dest-dir>
  local url=$1 sha=$2 dest=$3 archive
  archive=$(mktemp)
  curl -fsSL --retry 3 -o "$archive" "$url"
  echo "$sha  $archive" | sha256sum --check --quiet
  mkdir -p "$dest"
  # Each archive wraps its `include/` in one top-level directory named for
  # the target.
  tar --zstd -xf "$archive" -C "$dest" --strip-components=1
  rm -f "$archive"
}

glibc=https://github.com/cerisier/glibc-headers/releases/download/2.28-20250512
kernel=https://github.com/cerisier/kernel-headers/releases/download/4.19.325-20250511

fetch "$glibc/x86_64-linux-gnu.2.28.tar.zst" \
  8015f4a710987439dfdcde7539b62cc5db52d2cd9456af5e2e297494f13c56f3 \
  "$dir/x86_64-unknown-linux-gnu/glibc"
fetch "$kernel/4.19.325-x86.tar.zst" \
  55b232aa55b9f4aedbed6a743db0a2b7f4e92bb07b3ffeeb614e9dda30d34851 \
  "$dir/x86_64-unknown-linux-gnu/kernel"
fetch "$glibc/aarch64-linux-gnu.2.28.tar.zst" \
  a0f8d45193c814d4b77452ee921cbba49cdd60b9d2e41af28d555b03a4522857 \
  "$dir/aarch64-unknown-linux-gnu/glibc"
fetch "$kernel/4.19.325-arm64.tar.zst" \
  cf53102c75cf2bdc94c6302fc066806b15dddb4f4c400edef7fc3b7566e64d6b \
  "$dir/aarch64-unknown-linux-gnu/kernel"

here=$(cd "$(dirname "$0")" && pwd)
for triple in x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu; do
  echo "$here/regenerate.sh $triple $dir/$triple/glibc/include $dir/$triple/kernel/include"
done
