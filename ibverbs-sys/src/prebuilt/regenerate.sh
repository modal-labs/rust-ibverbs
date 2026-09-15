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
# Runs the crate's build script with bindgen pointed at those headers and
# copies the result over src/prebuilt/bindings_<arch>_linux.rs. Needs clang
# (libclang) and the rust target installed; no cmake or libnl, since the
# headers verbs.h needs are static files in the vendored rdma-core.
set -euo pipefail

triple=${1:?target triple}
glibc_include=${2:?glibc include dir}
kernel_include=${3:?kernel include dir}
clang_include=${4:-$(dirname "$(clang -print-file-name=include/stddef.h)")}

case "$triple" in
  x86_64-unknown-linux-gnu) out=bindings_x86_64_linux.rs ;;
  aarch64-unknown-linux-gnu) out=bindings_aarch64_linux.rs ;;
  *) echo "no prebuilt bindings slot for $triple" >&2; exit 2 ;;
esac

here=$(cd "$(dirname "$0")" && pwd)
crate=$(cd "$here/../.." && pwd)
vendor="$crate/vendor/rdma-core"
[ -f "$vendor/libibverbs/verbs.h" ] || {
  echo "vendored rdma-core missing; run: git submodule update --init" >&2
  exit 1
}

# The include layout the build would otherwise get from cmake: verbs.h and
# its three includes, under the <infiniband/...> and <rdma/...> paths.
include=$(mktemp -d)
trap 'rm -rf "$include"' EXIT
mkdir -p "$include/infiniband" "$include/rdma"
ln -s "$vendor/libibverbs/verbs.h" "$include/infiniband/verbs.h"
ln -s "$vendor/libibverbs/verbs_api.h" "$include/infiniband/verbs_api.h"
ln -s "$vendor/kernel-headers/rdma/ib_user_ioctl_verbs.h" "$include/infiniband/ib_user_ioctl_verbs.h"
ln -s "$vendor/kernel-headers/rdma/ib_user_verbs.h" "$include/rdma/ib_user_verbs.h"

target_dir=$(mktemp -d)
trap 'rm -rf "$include" "$target_dir"' EXIT
RDMA_CORE_INCLUDE_DIR="$include" \
RDMA_CORE_LIB_DIR="$include" \
IBVERBS_SYS_NO_LINK=1 \
BINDGEN_EXTRA_CLANG_ARGS="-nostdlibinc -isystem $glibc_include -isystem $kernel_include -isystem $clang_include" \
  cargo build --quiet --manifest-path "$crate/Cargo.toml" --target "$triple" --target-dir "$target_dir"

generated=$(find "$target_dir/$triple" -path '*/ibverbs-sys-*/out/bindings.rs' | head -1)
[ -n "$generated" ] || { echo "build script produced no bindings.rs" >&2; exit 1; }
cp "$generated" "$here/$out"
echo "wrote $here/$out ($(md5sum < "$here/$out" | cut -c1-32))"
