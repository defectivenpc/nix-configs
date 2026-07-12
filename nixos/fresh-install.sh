#!/usr/bin/env bash

HOST=$1
TARGET_IP=$2
SOPS_FILE=./secrets.yaml

echo "Installing $HOST at IP $TARGET_IP"

# Create a temporary directory
temp=$(mktemp -d)

# Function to cleanup temporary directory on exit
cleanup() {
  rm -rf "$temp"
}
trap cleanup EXIT

install -d -m755 "$temp/var/lib/sops-nix"

sops -d --extract '["hosts"]["'"$HOST"'"]["age"]["privateKey"]' $SOPS_FILE > "$temp/var/lib/sops-nix/key.txt"

echo RUNNING NIXOS-ANYWHERE ON "$HOST"

nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$temp" \
  --flake ".#$HOST" \
  --disko-mode disko \
  --phases disko,install,reboot \
  --generate-hardware-config nixos-facter ./hardware/facter/"$HOST".json \
  --target-host root@"$TARGET_IP"
