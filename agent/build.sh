#!/bin/bash

# Orbiter Agent Build Script
# Builds the agent for multiple architectures and generates distribution files

set -e

VERSION="1.0.0"
BUILD_DIR="./bin"
DIST_DIR="./dist"

echo "========================================="
echo "Orbiter Agent Build Script"
echo "Version: $VERSION"
echo "========================================="

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Build for different architectures
echo ""
echo "Building for Linux amd64..."
GOOS=linux GOARCH=amd64 go build -ldflags "-s -w" -o "$BUILD_DIR/orbiter-agent-linux-amd64-v$VERSION" main.go

echo "Building for Linux arm64..."
GOOS=linux GOARCH=arm64 go build -ldflags "-s -w" -o "$BUILD_DIR/orbiter-agent-linux-arm64-v$VERSION" main.go

echo "Building for Linux armv7..."
GOOS=linux GOARCH=arm GOARM=7 go build -ldflags "-s -w" -o "$BUILD_DIR/orbiter-agent-linux-armv7-v$VERSION" main.go

echo ""
echo "Build complete! Binaries created:"
ls -lh "$BUILD_DIR"

# Generate SHA256 checksums
echo ""
echo "Generating SHA256 checksums..."
cd "$BUILD_DIR"
sha256sum orbiter-agent-* > checksums.sha256
cd ..

echo "Checksums generated:"
cat "$BUILD_DIR/checksums.sha256"

# Create version file
echo ""
echo "Creating version.json..."
cat > "$BUILD_DIR/version.json" <<EOF
{
  "version": "$VERSION",
  "buildDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "builds": [
    {
      "os": "linux",
      "arch": "amd64",
      "filename": "orbiter-agent-linux-amd64-v$VERSION"
    },
    {
      "os": "linux",
      "arch": "arm64",
      "filename": "orbiter-agent-linux-arm64-v$VERSION"
    },
    {
      "os": "linux",
      "arch": "armv7",
      "filename": "orbiter-agent-linux-armv7-v$VERSION"
    }
  ]
}
EOF

echo "version.json created:"
cat "$BUILD_DIR/version.json"

# Create installation script
echo ""
echo "Creating install.sh..."
cat > "$BUILD_DIR/install.sh" <<'INSTALL_EOF'
#!/bin/bash

# Orbiter Agent Installation Script

set -e

VERSION="1.0.0"
INSTALL_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/orbiter-agent.service"

echo "========================================="
echo "Orbiter Agent Installer"
echo "Version: $VERSION"
echo "========================================="

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        BINARY="orbiter-agent-linux-amd64-v$VERSION"
        ;;
    aarch64)
        BINARY="orbiter-agent-linux-arm64-v$VERSION"
        ;;
    armv7l)
        BINARY="orbiter-agent-linux-armv7-v$VERSION"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH"
echo "Using binary: $BINARY"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Download binary if not present
if [ ! -f "$BINARY" ]; then
    echo "Binary not found. Please download it first."
    exit 1
fi

# Install binary
echo "Installing agent to $INSTALL_DIR..."
cp "$BINARY" "$INSTALL_DIR/orbiter-agent"
chmod +x "$INSTALL_DIR/orbiter-agent"

# Create systemd service
echo "Creating systemd service..."
cat > "$SERVICE_FILE" <<'SERVICE'
[Unit]
Description=Orbiter Server Monitoring Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/orbiter-agent --port 7433 --token YOUR_TOKEN_HERE
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

echo ""
echo "========================================="
echo "Installation complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Edit $SERVICE_FILE and set your token"
echo "2. Run: systemctl daemon-reload"
echo "3. Run: systemctl enable orbiter-agent"
echo "4. Run: systemctl start orbiter-agent"
echo "5. Check status: systemctl status orbiter-agent"
echo ""
INSTALL_EOF

chmod +x "$BUILD_DIR/install.sh"

# Create distribution packages
echo ""
echo "Creating distribution packages..."

for binary in "$BUILD_DIR"/orbiter-agent-*-v$VERSION; do
    if [ -f "$binary" ]; then
        basename=$(basename "$binary")
        arch_name=$(echo "$basename" | sed "s/orbiter-agent-//;s/-v$VERSION//")
        
        echo "Packaging $arch_name..."
        
        # Create package directory
        pkg_dir="$DIST_DIR/orbiter-agent-$arch_name-v$VERSION"
        mkdir -p "$pkg_dir"
        
        # Copy files
        cp "$binary" "$pkg_dir/orbiter-agent"
        cp "$BUILD_DIR/install.sh" "$pkg_dir/"
        cp "$BUILD_DIR/version.json" "$pkg_dir/"
        cp "$BUILD_DIR/checksums.sha256" "$pkg_dir/"
        
        # Create README
        cat > "$pkg_dir/README.md" <<README
# Orbiter Agent v$VERSION

## Installation

1. Run the installation script:
   \`\`\`bash
   sudo ./install.sh
   \`\`\`

2. Edit the service file and set your token:
   \`\`\`bash
   sudo nano /etc/systemd/system/orbiter-agent.service
   \`\`\`

3. Start the service:
   \`\`\`bash
   sudo systemctl daemon-reload
   sudo systemctl enable orbiter-agent
   sudo systemctl start orbiter-agent
   \`\`\`

4. Check status:
   \`\`\`bash
   sudo systemctl status orbiter-agent
   \`\`\`

## Manual Installation

If you prefer to install manually:

\`\`\`bash
sudo cp orbiter-agent /usr/local/bin/
sudo chmod +x /usr/local/bin/orbiter-agent
/usr/local/bin/orbiter-agent --port 7433 --token YOUR_TOKEN
\`\`\`

## Usage

\`\`\`bash
orbiter-agent --port 7433 --token <your-token> --alert-endpoint <ibm-cloud-function-url>
\`\`\`

## Architecture

This package is for: $arch_name

## Support

For issues and documentation, visit: https://github.com/your-org/orbiter
README
        
        # Create tarball
        cd "$DIST_DIR"
        tar -czf "orbiter-agent-$arch_name-v$VERSION.tar.gz" "orbiter-agent-$arch_name-v$VERSION"
        cd ..
        
        echo "Created: orbiter-agent-$arch_name-v$VERSION.tar.gz"
    fi
done

echo ""
echo "========================================="
echo "Build Summary"
echo "========================================="
echo "Version: $VERSION"
echo "Binaries: $BUILD_DIR/"
echo "Packages: $DIST_DIR/"
echo ""
echo "Distribution packages:"
ls -lh "$DIST_DIR"/*.tar.gz

echo ""
echo "========================================="
echo "Upload to IBM Cloud Object Storage"
echo "========================================="
echo "To upload the packages to IBM Cloud Object Storage, use:"
echo ""
echo "ibmcloud cos upload --bucket orbiter-agent --key releases/v$VERSION/orbiter-agent-linux-amd64-v$VERSION.tar.gz --file $DIST_DIR/orbiter-agent-linux-amd64-v$VERSION.tar.gz"
echo "ibmcloud cos upload --bucket orbiter-agent --key releases/v$VERSION/orbiter-agent-linux-arm64-v$VERSION.tar.gz --file $DIST_DIR/orbiter-agent-linux-arm64-v$VERSION.tar.gz"
echo "ibmcloud cos upload --bucket orbiter-agent --key releases/v$VERSION/orbiter-agent-linux-armv7-v$VERSION.tar.gz --file $DIST_DIR/orbiter-agent-linux-armv7-v$VERSION.tar.gz"
echo "ibmcloud cos upload --bucket orbiter-agent --key releases/v$VERSION/version.json --file $BUILD_DIR/version.json"
echo ""
echo "Or use the IBM Cloud Console to upload manually."
echo ""
echo "Build complete!"

# Made with Bob
