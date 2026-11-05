#!/bin/bash
# Rust FFI build for iOS device and universal Apple Silicon/Intel simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"

cd "$ROOT/rust"
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios

# XCFramework simulator slice must contain every architecture Xcode may select.
mkdir -p "$ROOT/build"
lipo -create \
  target/aarch64-apple-ios-sim/release/libstikpair_ffi.a \
  target/x86_64-apple-ios/release/libstikpair_ffi.a \
  -output "$ROOT/build/libstikpair_ffi-simulator.a"

cd "$ROOT"
rm -rf "$ROOT/StikPairFFI.xcframework"
xcodebuild -create-xcframework \
  -library rust/target/aarch64-apple-ios/release/libstikpair_ffi.a -headers rust/include \
  -library build/libstikpair_ffi-simulator.a -headers rust/include \
  -output "$ROOT/StikPairFFI.xcframework"

echo "Built $ROOT/StikPairFFI.xcframework"
