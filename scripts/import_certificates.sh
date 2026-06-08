#!/bin/bash
set -euo pipefail

# Import Apple Developer certificates for code signing in CI environment
# This script creates a temporary keychain, imports the certificate, and sets it as default

echo "=== Importing Apple Developer Certificate ==="

# Check required environment variables
if [ -z "${CERTIFICATE_P12:-}" ]; then
  echo "Error: CERTIFICATE_P12 environment variable is required"
  exit 1
fi

if [ -z "${CERTIFICATE_PASSWORD:-}" ]; then
  echo "Error: CERTIFICATE_PASSWORD environment variable is required"
  exit 1
fi

# Configuration
KEYCHAIN_NAME="build.keychain"
KEYCHAIN_PASSWORD=$(openssl rand -base64 32)
CERTIFICATE_PATH=$(mktemp "${RUNNER_TEMP:-/tmp}/certificate.XXXXXXXX.p12")

# Decode certificate from base64
echo "Decoding certificate..."
echo "$CERTIFICATE_P12" | base64 --decode > "$CERTIFICATE_PATH"

# Create temporary keychain
echo "Creating temporary keychain..."
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

# Set keychain as default
security default-keychain -s "$KEYCHAIN_NAME"

# Unlock keychain
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

# Import certificate
echo "Importing certificate..."
security import "$CERTIFICATE_PATH" \
  -k "$KEYCHAIN_NAME" \
  -P "$CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/productsign

# Set keychain settings (timeout disabled, no lock on sleep)
security set-keychain-settings "$KEYCHAIN_NAME"

# Set key partition list to allow codesign to access the certificate
security set-key-partition-list \
  -S apple-tool:,apple: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_NAME"

# Verify certificate is available
echo "Verifying certificate..."
security find-identity -v -p codesigning "$KEYCHAIN_NAME"

# Clean up certificate file
rm -f "$CERTIFICATE_PATH"

echo "=== Certificate import complete ==="
