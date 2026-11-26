#!/bin/bash
set -e
echo "=== Installing Yosys and build dependencies ==="
apt-get update -qq
apt-get install -y -qq yosys cmake g++ tcl-dev tcl8.6-dev bison flex swig \
    libeigen3-dev zlib1g-dev automake autotools-dev libfmt-dev wget git \
    p7zip-full zstd
echo "=== Verifying Yosys ==="
yosys -V
echo "Done. Expected: Yosys 0.33 (or your distro's current version)."
