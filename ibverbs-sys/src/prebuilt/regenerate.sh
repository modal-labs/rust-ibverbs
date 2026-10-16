#!/usr/bin/env bash
# Regenerate the committed bindings for one target from a hermetic sysroot.
#
# The bindings embed glibc's pthread type layouts (inside ibv_context and
# friends), so they are a function of the target triple AND the glibc version
# whose headers bindgen parses. Consumers link against a fixed glibc, and the
# bindings must come from that glibc's headers rather than whatever the
# generating host happens to run, or the committed file is not reproducible.
# -nostdlibinc below is what keeps the host's /usr/include out of the parse.
#
# Usage:
#   regenerate.sh <triple> <glibc-include> <kernel-include> [<clang-builtin-include>]
#
#   <triple>                x86_64-unknown-linux-gnu | aarch64-unknown-linux-gnu
#   <glibc-include>         glibc headers for the target (bits/, sys/, ...)
#   <kernel-include>        Linux UAPI headers for the target (linux/, asm/, ...)
#   <clang-builtin-include> clang's own headers (stddef.h, stdint.h); defaults
#                           to the one belonging to the clang on PATH
#
# Runs the crate's build script against the vendored rdma-core headers, once
# without features and once with `efa`, and copies the results over
# src/prebuilt/bindings_<arch>_linux{,_efa}.rs. Needs clang (libclang) and the
# rust target installed.
set -euo pipefail

triple=${1:?target triple}
glibc_include=${2:?glibc include dir}
kernel_include=${3:?kernel include dir}
clang_include=${4:-$(dirname "$(clang -print-file-name=include/stddef.h)")}

case "$triple" in
  x86_64-unknown-linux-gnu) arch=x86_64 ;;
  aarch64-unknown-linux-gnu) arch=aarch64 ;;
  *) echo "no prebuilt bindings slot for $triple" >&2; exit 2 ;;
esac

here=$(cd "$(dirname "$0")" && pwd)
crate=$(cd "$here/../.." && pwd)
[ -f "$crate/vendor/rdma-core/libibverbs/verbs.h" ] || {
  echo "vendored rdma-core missing; run: git submodule update --init" >&2
  exit 1
}

target_dir=$(mktemp -d)
trap 'rm -rf "$target_dir"' EXIT

generate() { # <features> <output file>
  local features=$1 out=$2 generated
  rm -rf "$target_dir"/*
  IBVERBS_SYS_NO_LINK=1 \
  BINDGEN_EXTRA_CLANG_ARGS="-nostdlibinc -isystem $glibc_include -isystem $kernel_include -isystem $clang_include" \
    cargo build --quiet --manifest-path "$crate/Cargo.toml" --target "$triple" \
      --target-dir "$target_dir" --no-default-features --features "$features"
  generated=$(find "$target_dir/$triple" -path '*/ibverbs-sys-*/out/bindings.rs' | head -1)
  [ -n "$generated" ] || { echo "build script produced no bindings.rs" >&2; exit 1; }
  cp "$generated" "$here/$out"
  echo "wrote $here/$out ($(md5sum < "$here/$out" | cut -c1-32))"
}

generate "" "bindings_${arch}_linux.rs"
generate "efa" "bindings_${arch}_linux_efa.rs"
