#!/bin/bash

set -eu

dockerfile=$1
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
extension="${dockerfile##*.}"
echo "Testing $dockerfile => $extension"
podman build -t "$extension" -f "$SCRIPT_DIR/$dockerfile" -q .
podman run --rm --volume "$(readlink -f "$SCRIPT_DIR/../locally.sh"):/usr/bin/locally:z" -i "$extension" /bin/bash -s <<EOF
    set -eu
    whoami
if command -v make &> /dev/null; then
    echo "Invalid test, make already exists" && exit 1
else
    locally install make
    source locally enable 
    make --version
fi
EOF
podman rmi "$extension"
