# Pre-generated bindings

Bindgen output committed per target, used by the `prebuilt-bindings` feature so
that consumers can build without cmake, libclang, or the libnl development
packages. Each file is the exact `bindings.rs` the build script produces for
that target from the vendored `rdma-core` checkout and a fixed glibc, with
`efa` and `rdmacm` disabled (those bindings are not pre-generated).

The bindings embed glibc's pthread type layouts (`ibv_context`, `ibv_qp`,
`ibv_cq` and friends contain mutexes and condition variables), so a file is
specific to both the architecture and the glibc whose headers it was generated
from. They are generated against **glibc 2.28** and Linux **4.19** UAPI
headers, the oldest a consumer links against, from a hermetic sysroot rather
than the generating host's `/usr/include`.

The generated layout assertions (`["Size of ibv_qp"][size_of::<ibv_qp>() - N]`)
make a file compiled for the wrong architecture or glibc a compile error. They
do not detect a file generated from an older `rdma-core` than the one vendored:
that is what the `prebuilt-bindings` CI job checks, by regenerating every file
and diffing it against the commit.

## Regenerating

Required whenever the vendored `rdma-core` submodule is bumped or the bindgen
configuration in `build.rs` changes. `regenerate.sh` runs the build script's
bindgen path against a sysroot you point it at, so the output is reproducible
across hosts; `.github/workflows/check.yml` shows where CI obtains the
sysroots.

```sh
git submodule update --init
ibverbs-sys/src/prebuilt/regenerate.sh x86_64-unknown-linux-gnu \
    <glibc-2.28 include dir> <linux-4.19 uapi include dir>
ibverbs-sys/src/prebuilt/regenerate.sh aarch64-unknown-linux-gnu \
    <glibc-2.28 include dir> <linux-4.19 uapi include dir>
```

Targets with committed bindings:

- `bindings_x86_64_linux.rs` — `x86_64-unknown-linux-gnu`
- `bindings_aarch64_linux.rs` — `aarch64-unknown-linux-gnu`
