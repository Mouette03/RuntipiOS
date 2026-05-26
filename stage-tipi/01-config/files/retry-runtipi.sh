#!/bin/bash
# TipiOS — relance l'installation de runTipi si le flag d'échec existe.
# Lancé par tipi-runtipi-retry.service au démarrage.

FLAG=/boot/firmware/tipi-install-failed.flag

[ -f "$FLAG" ] || exit 0

echo "TipiOS: flag d'échec détecté — nouvelle tentative d'installation de runTipi…"
rm -f "$FLAG"

curl -sSL https://setup.runtipi.io | bash
