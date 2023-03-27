#!/bin/bash

set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

tests=(
    "Dockerfile.almalinux8"
    "Dockerfile.almalinux9"
    # "Dockerfile.centos7"
    "Dockerfile.debian10"
    "Dockerfile.debian11"
    "Dockerfile.rockylinux8"
    "Dockerfile.rockylinux9"
    "Dockerfile.suse15"
    "Dockerfile.sles15"
    "Dockerfile.ubuntu20_04"
    "Dockerfile.ubuntu22_04"
    "Dockerfile.rhel8"
    "Dockerfile.rhel9"
)

for dockerfile in "${tests[@]}"; do

    extension="${dockerfile##*.}"
    echo "Testing $dockerfile => $extension"
    docker build -t "$extension" -f "$SCRIPT_DIR/$dockerfile" -q .
    docker run --rm -v "$SCRIPT_DIR/../locally.sh:/usr/bin/locally" -i "$extension" /bin/bash -s <<EOF
    set -eu
if command -v make &> /dev/null; then
    echo "Invalid test, make already exists" && exit 1
else
    locally install make
    source locally enable 
    make --version
fi
EOF
    docker rmi "$extension"
done
