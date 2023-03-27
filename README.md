# Locally

Locally is a special package manager that allows you to use your normal system-managed (e.g dnf, apt, zypper, etc.) packages locally at a specified prefix *without root*.
Essentially, an unprivileged user (e.g in HPC, education, or work settings) can now install most software of the distro somewhere in the home directory.

Locally achieves this by invoking the actual system package manager but only for resolving dependencies and downloading packages from mirrors.
Once the packages are downloaded, a prefixed installation is done where we extract the content of the packages to a writeable prefix.
Once installed, packages can be made available by prepending to the correct environment variables (e.g `PATH`, `LD_LIBRARY_PATH`).

## Quick start

```shell
locally install nano # no sudo required
source locally enable


```

## FAQ

### What about systemd?

It's likely a systemd package will be installed as an indirect dependency, however, this is parallel to your system's own systemd daemon running with root so it's mostly useless.
