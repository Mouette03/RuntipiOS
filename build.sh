#!/bin/bash
# Local build script for RuntipiOS

set -e

echo "==> Building RuntipiOS..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Create output directory
mkdir -p output

# Build the Docker image
echo "==> Building Docker image..."
docker build -t runtipios-builder:latest .

# Run the builder
echo "==> Running ISO builder..."
docker run --rm --privileged \
    -v "$(pwd)/output:/build/output" \
    runtipios-builder:latest

echo ""
echo "==> Build complete!"
echo "==> ISO file location:"
ls -lh output/*.iso

echo ""
echo "==> To write the ISO to a USB drive:"
echo "    sudo dd if=output/RuntipiOS-*.iso of=/dev/sdX bs=4M status=progress && sync"
echo "    (Replace /dev/sdX with your USB drive)"
