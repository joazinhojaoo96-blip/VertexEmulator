#!/bin/bash
# Rust FFI build for iOS device and Apple Silicon simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"

cd "$ROOT/rust"
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim

cd "$ROOT"
rm -rf "$ROOT/StikPairFFI.xcframework"
xcodebuild -create-xcframework \
  -library rust/target/aarch64-apple-ios/release/libstikpair_ffi.a -headers rust/include \
  -library rust/target/aarch64-apple-ios-sim/release/libstikpair_ffi.a -headers rust/include \
  -output "$ROOT/StikPairFFI.xcframework"

echo "Built $ROOT/StikPairFFI.xcframework"
