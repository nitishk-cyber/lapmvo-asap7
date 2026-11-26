#!/bin/bash
set -e
WORKDIR="$(pwd)"
mkdir -p asap7_libs

echo "=== Cloning ASAP7 liberty repo (large, ~5.7GB before cleanup) ==="
if [ ! -d asap7_full ]; then
  git clone --depth 1 https://github.com/The-OpenROAD-Project/asap7sc7p5t_28.git asap7_full
fi

echo "=== Extracting NLDM liberty for SIMPLE/INVBUF/SEQ, all Vt flavors and corners ==="
cd asap7_full/LIB/NLDM
for grp in SIMPLE INVBUF SEQ; do
  for vt in RVT LVT SLVT; do
    for corner in TT SS FF; do
      f=$(find . -maxdepth 1 -iname "asap7sc7p5t_${grp}_${vt}_${corner}_nldm_*.lib.7z" | head -1)
      if [ -n "$f" ]; then
        7z x -y -o"$WORKDIR/asap7_libs" "$f" > /dev/null 2>&1
      fi
    done
  done
done
cd "$WORKDIR"

echo "=== Building combined SIMPLE+INVBUF libraries (needed for ABC technology mapping) ==="
cd asap7_libs
for vt in RVT LVT SLVT; do
  for corner in TT SS FF; do
    simple=$(ls asap7sc7p5t_SIMPLE_${vt}_${corner}_nldm_*.lib 2>/dev/null | head -1)
    invbuf=$(ls asap7sc7p5t_INVBUF_${vt}_${corner}_nldm_*.lib 2>/dev/null | head -1)
    if [ -n "$simple" ] && [ -n "$invbuf" ]; then
      startline=$(grep -n "^\s*cell (" "$invbuf" | head -1 | cut -d: -f1)
      totallines=$(wc -l < "$invbuf")
      endline=$((totallines - 1))
      sed -n "${startline},${endline}p" "$invbuf" > /tmp/invbuf_cells.txt
      simplelines=$(wc -l < "$simple")
      simpleend=$((simplelines - 1))
      sed -n "1,${simpleend}p" "$simple" > combined_${vt}_${corner}.lib
      cat /tmp/invbuf_cells.txt >> combined_${vt}_${corner}.lib
      echo "}" >> combined_${vt}_${corner}.lib
    fi
  done
done
cd "$WORKDIR"

echo "=== Cleaning up the large repo (keep only extracted libs) ==="
rm -rf asap7_full cudd-3.0.0.tar.gz

echo "Done. Liberty files in: $WORKDIR/asap7_libs/"
ls asap7_libs/*.lib | wc -l
echo "files present. Expected: ~27 base files + 9 combined files."
