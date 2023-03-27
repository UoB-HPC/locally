#!/bin/bash

was_modified_between() {
  local file=$1
  local start=$2
  local end=$3
  mod_time=$(stat -c "%.3Z" "$file" | tr -d '.')
  ((mod_time >= start)) && ((mod_time <= end)) && return
  false
}

get_os_release() {
  # cat /etc/os-release
  local line
  while read -r line; do
    if [[ "$line" == *"="* ]]; then
      eval "local $line"
    fi
  done </etc/os-release
  echo "${!1}"
}

get_id() {
  get_os_release "ID"
}

get_cache() {
  echo "$1/cache"
}

get_prefix() {
  echo "$1/$(uname -m)/$(get_id)"
}

get_modulefiles() {
  echo "$1/modulefiles"
}

run_install() {

  set -eu

  in_dir="$1"
  cache_dir=$(get_cache "$in_dir")
  prefix_dir=$(get_prefix "$in_dir")
  requested="${@:2}"

  mkdir -p "$cache_dir"
  mkdir -p "$prefix_dir"

  local package_type packages id start end

  id="$(get_id)"
  start=$(date +"%s%3N")
  case "$id" in
  almalinux | fedora | rhel | centos | rocky | amzn)
    package_type="rpm"
    if [ ! -x "$(command -v dnf)" ]; then
      echo "yum not implemented"
      exit 1
    fi

    # See if we're on an EL platform, if so, add EPEL

    # shellcheck disable=SC2086
    dnf download --nogpgcheck --resolve --alldeps --downloaddir $cache_dir --arch "$(uname -m)" \
      --repofrompath centos-appstream,https://vault.centos.org/centos/8/AppStream/x86_64/os \
      --repofrompath centos-base,https://vault.centos.org/centos/8/BaseOS/x86_64/os \
      $requested

    packages=$(find "$cache_dir" -type f -name "*.rpm")
    ;;
  sles | opensuse-*)
    package_type="rpm"
    # shellcheck disable=SC2086
    zypper --reposd-dir /etc/zypp/repos.d/ \
      --root $cache_dir --cache-dir $cache_dir --non-interactive --no-gpg-checks \
      --releasever "$(get_os_release "VERSION_ID")" \
      install --download-only $requested || true
    packages=$(find "$cache_dir/packages" -type f -name "*.rpm")
    ;;
  ubuntu | debian)
    package_type="deb"
    (
      cd "$cache_dir" || (
        echo "Bad cache dir $cache_dir"
        exit 1
      )
      # shellcheck disable=SC2046,SC2086
      apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests \
        --no-conflicts --no-breaks --no-replaces --no-enhances \
        --no-pre-depends $requested | grep "^\w")
    )
    packages=$(find "$cache_dir" -type f -name "*.deb")
    ;;
  *)
    echo "Unsupported OS: $id" && exit 1
    ;;
  esac
  end=$(date +"%s%3N")

  case "$package_type" in
  rpm)
    echo "$packages" | while read -r file; do
      name=$(rpm -qp --queryformat '%{NAME}\n' "$file")
      case $name in
      filesystem | setup) echo "Skipping system package: $name" ;;
      *)
        if was_modified_between "$file" "$start" "$end"; then
          if [ "$(rpm -qp --scripts "$file")" ]; then echo "[WARN] $file has scripts"; fi # warn if script is non-empty
          (
            cd "$prefix_dir"
            rpm2cpio "$file" | cpio -idmu --no-absolute-filenames --no-preserve-owner --quiet
            echo "Installed $name ($file) to $prefix_dir"
            # rpm2archive --nocompression "$file"
            # tar --no-same-owner --no-same-permissions --overwrite -xf "$file.tar"
          )
        fi
        ;;
      esac
    done
    ;;
  deb)
    echo "$packages" | while read -r file; do
      name=$(dpkg -f "$file" Package)
      if was_modified_between "$file" "$start" "$end"; then
        dpkg-deb -x "$file" "$prefix_dir"
        echo "Installed $name ($file) to $prefix_dir"
      fi
    done
    ;;
  *)
    echo "Unsupported package type $package_type"
    ;;
  esac

  set +eu
}

setup_modulefile() {
  set -eu
  local in_dir="$1"
  modulefiles=$(get_modulefiles "$in_dir")
  mkdir -p "$modulefiles"
  modulefile="$modulefiles/locally"

  if [ ! -f "$modulefile" ]; then
    cat >"$modulefile" <<EOF
#%Module1.0
prepend-path  PATH             $prefix_dir/bin
prepend-path  PATH             $prefix_dir/usr/bin
prepend-path  CPATH            $prefix_dir/usr/include
prepend-path  LIBRARY_PATH     $prefix_dir/lib64
prepend-path  LIBRARY_PATH     $prefix_dir/lib
prepend-path  LD_LIBRARY_PATH  $prefix_dir/lib64
prepend-path  LD_LIBRARY_PATH  $prefix_dir/lib
prepend-path  LD_LIBRARY_PATH  $prefix_dir/lib/$(uname -m)-linux-gnu
prepend-path  MANPATH          $prefix_dir/usr/share/man
EOF
  fi
  echo "For environment modules: module use $modulefiles"
  set +eu
}

in_dir=$HOME/.locally
action=""
packages=""

# locally --in R --install PACKAGE_1 PACKAGE_2 PACKAGE_N...
# locally --in R
print_help() {
  cat <<EOF

usage: $0 [--in IN_DIR] [enable]|[install [PACKAGES]...] 

Install a normal system-managed (e.g dnf, apt, zypper, etc.) package locally at the specified prefix without root.

The installed package can then be made available with:

    source $0 enable

Which persists throughout the current shell session.
Alternatively, a modulefile is to IN_DIR which can be loaded using:

    module use \$IN_DIR/modulefiles
    module load locally

The module method of loading gives you the flexibility to load and unload all packages.
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
  --help)
    print_help
    ;;
  --in | in)
    in_dir="$2"
    shift # past argument
    shift # past value
    ;;
  --enable | enable)
    action="enable"
    shift # past value
    ;;
  --install | install)
    action="install"
    shift # past argument
    ;;
  *)
    packages="$packages $1"
    shift # past argument
    ;;
  esac
done

# echo "In: $in_dir"
# echo "Packages: $packages"

case "$action" in
install)
  # shellcheck disable=SC2086
  run_install "$in_dir" $packages
  setup_modulefile "$in_dir"
  ;;
enable)
  if (return 0 2>/dev/null); then
    prefix=$(get_prefix "$in_dir")
    echo "Enabling prefix at $prefix"
    export PATH="$prefix/usr/bin:$prefix/bin:${PATH:-}"
    export CPATH="$prefix/usr/include:${CPATH:-}"
    export LIBRARY_PATH="$prefix/lib64:/$prefix/lib:${LIBRARY_PATH:-}"
    export LD_LIBRARY_PATH="$prefix/lib64:/$prefix/lib:/$prefix/lib/$(uname -m)-linux-gnu:${LD_LIBRARY_PATH:-}"
    export MANPATH="$prefix/usr/share/man:${MANPATH:-}"
  else
    echo "You must source this script to enable prefix, e.g: source $0 enable" && exit 1
  fi
  ;;
esac

echo "Done"
