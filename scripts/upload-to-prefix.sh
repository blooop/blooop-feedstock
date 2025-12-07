#!/bin/bash
set -e

# upload-to-prefix.sh - Upload conda packages to prefix.dev
# Usage: ./upload-to-prefix.sh <output_dir> <channel_name>

OUTPUT_DIR=${1:-"output"}
CHANNEL=${2:-"blooop-tools"}

if [ -z "$PREFIX_API_KEY" ]; then
    echo "❌ PREFIX_API_KEY environment variable not set"
    echo "   Please set your prefix.dev API key:"
    echo "   export PREFIX_API_KEY=your_api_key_here"
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "❌ Output directory '$OUTPUT_DIR' does not exist"
    exit 1
fi

echo "📤 Uploading packages to prefix.dev/channels/$CHANNEL"
echo "📁 Looking for packages in: $OUTPUT_DIR"

# Find all conda packages
PACKAGES=$(find "$OUTPUT_DIR" -name "*.conda" -o -name "*.tar.bz2")

if [ -z "$PACKAGES" ]; then
    echo "⚠️  No conda packages found in $OUTPUT_DIR"
    exit 0
fi

UPLOAD_COUNT=0
FAILED_COUNT=0

for package in $PACKAGES; do
    if [ -f "$package" ]; then
        package_name=$(basename "$package")
        package_size=$(du -h "$package" | cut -f1)
        
        echo "📦 Uploading $package_name ($package_size)..."
        
        # Upload to prefix.dev using their API
        # Note: This is a placeholder - you'll need to adapt this to prefix.dev's actual API
        # The exact endpoint and method may vary
        
        if curl -f -X POST \
            -H "Authorization: Bearer ${PREFIX_API_KEY}" \
            -H "Content-Type: application/octet-stream" \
            --data-binary "@${package}" \
            "https://prefix.dev/api/v1/channels/${CHANNEL}/packages" > /dev/null 2>&1; then
            
            echo "✅ Successfully uploaded $package_name"
            ((UPLOAD_COUNT++))
        else
            echo "❌ Failed to upload $package_name"
            ((FAILED_COUNT++))
            
            # Try alternative upload method if the first fails
            echo "   Retrying with multipart form..."
            if curl -f -X POST \
                -H "Authorization: Bearer ${PREFIX_API_KEY}" \
                -F "package=@${package}" \
                "https://prefix.dev/api/v1/channels/${CHANNEL}/upload" > /dev/null 2>&1; then
                
                echo "✅ Successfully uploaded $package_name (retry)"
                ((UPLOAD_COUNT++))
                ((FAILED_COUNT--))
            else
                echo "❌ Failed to upload $package_name (both methods failed)"
            fi
        fi
    fi
done

echo ""
echo "📊 Upload Summary:"
echo "   ✅ Successful uploads: $UPLOAD_COUNT"
echo "   ❌ Failed uploads: $FAILED_COUNT"

if [ $FAILED_COUNT -gt 0 ]; then
    echo ""
    echo "⚠️  Some uploads failed. Please check:"
    echo "   - Your PREFIX_API_KEY is valid and has upload permissions"
    echo "   - The channel '$CHANNEL' exists and you have access"
    echo "   - Network connectivity to prefix.dev"
    exit 1
fi

echo ""
echo "🎉 All packages uploaded successfully!"
echo "🌐 View your channel at: https://prefix.dev/channels/$CHANNEL"