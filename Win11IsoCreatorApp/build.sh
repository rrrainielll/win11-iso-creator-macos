#!/bin/bash
set -e

# App details
APP_NAME="Win11 ISO Creator"
EXECUTABLE_NAME="Win11IsoCreatorApp"

# Project paths
SOURCE_ROOT=$(dirname "$0")
BUILD_DIR="${SOURCE_ROOT}/.build"
FINAL_APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
RELEASE_BUILD_DIR="${BUILD_DIR}/release"

echo "Starting build for ${APP_NAME}..."

# 1. Build the Swift package in release configuration
echo "Building Swift package..."
swift build --package-path "$SOURCE_ROOT" -c release
if [ $? -ne 0 ]; then
    echo "Swift build failed."
    exit 1
fi

# 2. Create the .app bundle directory structure
echo "Creating app bundle structure at ${FINAL_APP_PATH}..."
rm -rf "$FINAL_APP_PATH"
mkdir -p "${FINAL_APP_PATH}/Contents/MacOS"
mkdir -p "${FINAL_APP_PATH}/Contents/Resources"

# 3. Copy the compiled executable to the MacOS directory
echo "Copying executable..."
cp "${RELEASE_BUILD_DIR}/${EXECUTABLE_NAME}" "${FINAL_APP_PATH}/Contents/MacOS/"
if [ $? -ne 0 ]; then
    echo "Failed to copy executable."
    exit 1
fi

# 4. Copy the Info.plist to the Contents directory
echo "Copying Info.plist..."
cp "${SOURCE_ROOT}/Sources/${EXECUTABLE_NAME}/Info.plist" "${FINAL_APP_PATH}/Contents/"
if [ $? -ne 0 ]; then
    echo "Failed to copy Info.plist."
    exit 1
fi

# 5. Compile the Asset Catalog and move it to the Resources directory
echo "Compiling asset catalog..."
/Applications/Xcode.app/Contents/Developer/usr/bin/actool "${SOURCE_ROOT}/Sources/${EXECUTABLE_NAME}/Assets.xcassets" \
    --compile "${FINAL_APP_PATH}/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 12.0
if [ $? -ne 0 ]; then
    echo "Asset catalog compilation failed."
    exit 1
fi

echo ""
echo "----------------------------------------"
echo "Build succeeded!"
echo "App bundle created at:"
echo "${FINAL_APP_PATH}"
echo "----------------------------------------"
