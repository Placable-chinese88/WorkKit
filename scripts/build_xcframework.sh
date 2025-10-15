#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Error: Code signing identity required"
    echo "Usage: $0 <codesign-identity>"
    echo "Example: $0 \"Developer ID Application: Your Name (TEAM_ID)\""
    echo ""
    echo "To find your signing identities, run:"
    echo "  security find-identity -v -p codesigning"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

SNAPPY_SOURCE_DIR="$PROJECT_ROOT/vendor/snappy"
BUILD_DIR="$PROJECT_ROOT/.build/build_xcframework"
OUTPUT_DIR="$PROJECT_ROOT/.build/xcframework_output"
FRAMEWORK_NAME="libsnappy"

CODESIGN_IDENTITY="$1"

rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

build_platform() {
    local PLATFORM=$1
    local ARCH=$2
    local SDK=$3
    local PLATFORM_DIR=$4
    
    local BUILD_SUBDIR="$BUILD_DIR/$PLATFORM_DIR"
    mkdir -p "$BUILD_SUBDIR"
    
    local MIN_IOS_VERSION="12.0"
    local MIN_MACOS_VERSION="10.13"
    
    local CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_ARCHITECTURES=$ARCH \
        -DCMAKE_OSX_SYSROOT=$SDK \
        -DSNAPPY_BUILD_TESTS=OFF \
        -DSNAPPY_BUILD_BENCHMARKS=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_INSTALL_PREFIX=$BUILD_SUBDIR/install \
        -DCMAKE_C_FLAGS=-fembed-bitcode \
        -DCMAKE_CXX_FLAGS=-fembed-bitcode"
    
    case $PLATFORM in
        "iOS")
            CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN_IOS_VERSION"
            ;;
        "iOS Simulator")
            CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN_IOS_VERSION"
            ;;
        "macOS")
            CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN_MACOS_VERSION"
            ;;
    esac
    
    cd "$BUILD_SUBDIR"
    cmake $CMAKE_FLAGS "$SNAPPY_SOURCE_DIR"
    make -j$(sysctl -n hw.ncpu)
    make install
    cd "$SNAPPY_SOURCE_DIR"
}

build_platform "iOS" "arm64" "iphoneos" "ios-arm64"
build_platform "iOS Simulator" "arm64" "iphonesimulator" "ios-simulator-arm64"
build_platform "iOS Simulator" "x86_64" "iphonesimulator" "ios-simulator-x86_64"
build_platform "macOS" "arm64" "macosx" "macos-arm64"
build_platform "macOS" "x86_64" "macosx" "macos-x86_64"

mkdir -p "$OUTPUT_DIR/ios-arm64_x86_64-simulator/Headers"
lipo -create \
    "$BUILD_DIR/ios-simulator-arm64/install/lib/libsnappy.a" \
    "$BUILD_DIR/ios-simulator-x86_64/install/lib/libsnappy.a" \
    -output "$OUTPUT_DIR/ios-arm64_x86_64-simulator/libsnappy.a"

mkdir -p "$OUTPUT_DIR/macos-arm64_x86_64/Headers"
lipo -create \
    "$BUILD_DIR/macos-arm64/install/lib/libsnappy.a" \
    "$BUILD_DIR/macos-x86_64/install/lib/libsnappy.a" \
    -output "$OUTPUT_DIR/macos-arm64_x86_64/libsnappy.a"

mkdir -p "$OUTPUT_DIR/ios-arm64/Headers"
cp "$BUILD_DIR/ios-arm64/install/lib/libsnappy.a" "$OUTPUT_DIR/ios-arm64/libsnappy.a"

for PLATFORM_DIR in ios-arm64 ios-arm64_x86_64-simulator macos-arm64_x86_64; do
    cp "$BUILD_DIR/ios-arm64/install/include/"*.h "$OUTPUT_DIR/$PLATFORM_DIR/Headers/"
done

for PLATFORM_DIR in ios-arm64 ios-arm64_x86_64-simulator macos-arm64_x86_64; do
    codesign --force --sign "$CODESIGN_IDENTITY" "$OUTPUT_DIR/$PLATFORM_DIR/libsnappy.a"
done

xcodebuild -create-xcframework \
    -library "$OUTPUT_DIR/ios-arm64/libsnappy.a" \
    -headers "$OUTPUT_DIR/ios-arm64/Headers" \
    -library "$OUTPUT_DIR/ios-arm64_x86_64-simulator/libsnappy.a" \
    -headers "$OUTPUT_DIR/ios-arm64_x86_64-simulator/Headers" \
    -library "$OUTPUT_DIR/macos-arm64_x86_64/libsnappy.a" \
    -headers "$OUTPUT_DIR/macos-arm64_x86_64/Headers" \
    -output "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"

codesign --force --sign "$CODESIGN_IDENTITY" --timestamp "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"

echo "✓ XCFramework created at: $OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"