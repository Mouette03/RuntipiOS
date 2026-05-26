#!/bin/bash -e
# Copie le rootfs du stage précédent (stage2) vers stage-tipi.
# Sans cette étape, le stage n'a aucun rootfs à modifier.
if [ ! -d "${ROOTFS_DIR}" ]; then
    copy_previous
fi
