#!/bin/bash
# Validation script to check RuntipiOS build files

set -e

echo "==> RuntipiOS Build Validation Script"
echo ""

ERRORS=0
WARNINGS=0

# Function to check file existence
check_file() {
    if [ -f "$1" ]; then
        echo "✓ $1 exists"
        return 0
    else
        echo "✗ $1 is missing"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Function to check directory existence
check_dir() {
    if [ -d "$1" ]; then
        echo "✓ $1 exists"
        return 0
    else
        echo "✗ $1 is missing"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Check core files
echo "==> Checking core files..."
check_file "Dockerfile"
check_file "build-config.yml"
check_file "build.sh"
check_file ".gitignore"
check_file "README.md"

echo ""
echo "==> Checking scripts directory..."
check_dir "scripts"
check_file "scripts/build-iso.sh"
check_file "scripts/parse-config.py"
check_file "scripts/chroot-setup.sh"
check_file "scripts/setup-bootloader.sh"

echo ""
echo "==> Checking firstboot scripts..."
check_dir "scripts/firstboot"
check_file "scripts/firstboot/firstboot.sh"
check_file "scripts/firstboot/gui-installer.py"
check_file "scripts/firstboot/text-installer.sh"
check_file "scripts/firstboot/install-runtipi.sh"

echo ""
echo "==> Checking GitHub workflows..."
check_dir ".github/workflows"
check_file ".github/workflows/build-release.yml"

# Check script permissions
echo ""
echo "==> Checking script permissions..."
for script in build.sh scripts/*.sh scripts/firstboot/*.sh scripts/firstboot/*.py scripts/*.py; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo "✓ $script is executable"
        else
            echo "⚠ $script is not executable"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
done

# Validate shell scripts
echo ""
echo "==> Validating shell script syntax..."
for script in build.sh scripts/*.sh scripts/firstboot/*.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            echo "✓ $script syntax is valid"
        else
            echo "✗ $script has syntax errors"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Validate Python scripts
echo ""
echo "==> Validating Python script syntax..."
for script in scripts/*.py scripts/firstboot/*.py; do
    if [ -f "$script" ]; then
        if python3 -m py_compile "$script" 2>/dev/null; then
            echo "✓ $script syntax is valid"
        else
            echo "✗ $script has syntax errors"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Validate YAML files
echo ""
echo "==> Validating YAML files..."
if command -v python3 > /dev/null 2>&1; then
    for yaml_file in build-config.yml .github/workflows/*.yml; do
        if [ -f "$yaml_file" ]; then
            if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
                echo "✓ $yaml_file is valid"
            else
                echo "✗ $yaml_file has syntax errors"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    done
else
    echo "⚠ Python3 not found, skipping YAML validation"
    WARNINGS=$((WARNINGS + 1))
fi

# Check Docker availability
echo ""
echo "==> Checking Docker..."
if command -v docker > /dev/null 2>&1; then
    echo "✓ Docker is installed"
    if docker ps > /dev/null 2>&1; then
        echo "✓ Docker is running"
    else
        echo "⚠ Docker daemon is not running"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "⚠ Docker is not installed (required for building)"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "==================================="
echo "Validation Summary"
echo "==================================="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [ $ERRORS -eq 0 ]; then
    echo ""
    echo "✓ All validations passed!"
    if [ $WARNINGS -gt 0 ]; then
        echo "⚠ There are $WARNINGS warning(s) that should be addressed"
    fi
    exit 0
else
    echo ""
    echo "✗ Validation failed with $ERRORS error(s)"
    exit 1
fi
