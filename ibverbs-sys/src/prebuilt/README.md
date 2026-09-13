# Pre-generated bindings

Bindgen output committed per target, used by the `prebuilt-bindings` feature so
that consumers can build without cmake, libclang, or the libnl development
packages. Each file is the exact `bindings.rs` the build script produces from
the vendored `rdma-core` checkout for that target, with `efa` and `rdmacm`
disabled (those bindings are not pre-generated).

Safety: the generated layout assertions (`const _: () = { ["Size of ..."] ... }`)
turn a stale or wrong-target file into a compile error, so a mismatch cannot
produce a silently wrong ABI.

## Regenerating

Required whenever the vendored `rdma-core` submodule is bumped or the bindgen
configuration in `build.rs` changes, for every file in this directory:

```sh
cargo clean -p ibverbs-sys
cargo build -p ibverbs-sys  # no features: the vendored cmake + bindgen path
cp "$(find target/debug/build/ibverbs-sys-*/out/bindings.rs | head -1)" \
   ibverbs-sys/src/prebuilt/bindings_<target>.rs
```

Targets with committed bindings:

- `bindings_x86_64_linux.rs` — `x86_64-unknown-linux-gnu` (glibc). The glibc
  pthread type layouts embedded in `ibv_context` and friends differ across
  architectures and libcs, which is why bindings are committed per target.
