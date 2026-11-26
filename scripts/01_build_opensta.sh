#!/bin/bash
set -e
WORKDIR="$(pwd)"

echo "=== Downloading and building CUDD 3.0.0 ==="
if [ ! -f cudd-3.0.0.tar.gz ]; then
  wget -q https://raw.githubusercontent.com/davidkebo/cudd/main/cudd_versions/cudd-3.0.0.tar.gz
fi
if [ ! -d cudd-3.0.0 ]; then
  tar -xzf cudd-3.0.0.tar.gz
  cd cudd-3.0.0
  ./configure
  make -j"$(nproc)" cudd/libcudd.la
  cd "$WORKDIR"
fi
echo "CUDD build complete: $(ls cudd-3.0.0/cudd/.libs/libcudd.a)"

echo "=== Cloning OpenSTA ==="
if [ ! -d opensta_src ]; then
  git clone --depth 1 https://github.com/parallaxsw/OpenSTA.git opensta_src
fi

echo "=== Building OpenSTA (this is the slow step) ==="
mkdir -p opensta_src/build
cd opensta_src/build
cmake -DCUDD_DIR="$WORKDIR/cudd-3.0.0" ..
make -j"$(nproc)"
cd "$WORKDIR"

echo "=== Verifying OpenSTA ==="
echo "help" | ./opensta_src/build/sta -no_init -exit 2>&1 | head -1

echo "Done. Binary at: $WORKDIR/opensta_src/build/sta"
echo "Expected: OpenSTA 3.1.0 (commit e9c075ab94 or current upstream head)"
