#!/bin/bash

set -eu

dockerfile=$1
package=$2
validate=$3

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
extension="${dockerfile##*.}"
echo "Testing $dockerfile => $extension"
podman build -t "$extension" -f "$SCRIPT_DIR/$dockerfile" -q .
podman run --rm --volume "$(readlink -f "$SCRIPT_DIR/../locally.sh"):/usr/bin/locally:z" -i "$extension" /bin/bash -s <<EOF
    set -eu
    whoami
if command -v $package &> /dev/null; then
    echo "Invalid test, $package already exists" && exit 1
else
    locally install $package
    source locally enable 
    $validate
fi
EOF
podman rmi "$extension"
echo "Done"
