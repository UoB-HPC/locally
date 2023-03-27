#!/bin/bash

dest="$HOME/.local/bin"
mkdir -p "$dest"
curl https://raw.githubusercontent.com/UoB-HPC/locally/master/locally.sh -o "$dest/locally"
chmod +x "$dest/locally"
echo "locally installed to $dest/locally"

if ! command -v locally &>/dev/null; then
  echo "locally appears to be unavailable on PATH, you may need to add $dest to PATH:"
  echo "    echo \"export PATH=$dest:\$PATH\" >> ~/.bashrc"
fi

echo "All done! Run \`locally --help\` for next steps."
