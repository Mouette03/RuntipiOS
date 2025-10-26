#!/usr/bin/env python3
import yaml
import sys

# Parse build-config.yml and output shell variables
with open('/build/build-config.yml', 'r') as f:
    config = yaml.safe_load(f)

# Output shell variables
print(f"RELEASE={config['base']['release']}")
print(f"ARCH={config['base']['architecture']}")
print(f"ISO_NAME={config['iso']['name']}")
print(f"ISO_VERSION={config['iso']['version']}")
print(f"ISO_LABEL={config['iso']['label']}")

# Export package list
packages = ' '.join(config['packages'])
print(f"PACKAGES='{packages}'")
