#!/bin/bash
# RuntipiOS — relance l'installation de Runtipi si le flag d'échec existe.
# Lancé par tipi-runtipi-retry.service au démarrage.

FLAG=/boot/firmware/tipi-install-failed.flag

[ -f "$FLAG" ] || exit 0

echo "RuntipiOS: flag d'échec détecté — nouvelle tentative d'installation de Runtipi…"
rm -f "$FLAG"

curl -sSL https://setup.runtipi.io | bash
