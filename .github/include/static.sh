#!/bin/bash
#
# This script is the entrypoint for the static build.
#
# To make CI errors easier to reproduce locally, please limit
# this script to using only git, docker, and coreutils.

set -eux

IMAGE=bpftrace-static
cd $(git rev-parse --show-toplevel)

# Build the base image
docker build -t "$IMAGE" -f docker/Dockerfile.static docker/

# Perform bpftrace static build
docker run -v $(pwd):$(pwd) -w $(pwd) -i "$IMAGE" <<'EOF'
set -eux
# Copy static libraries
find /usr -name "libpcap.a" -exec cp -f {} /usr/lib/ \;
BUILD_DIR=build-static
cmake -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release -DCMAKE_VERBOSE_MAKEFILE=ON -DBUILD_TESTING=OFF -DSTATIC_LINKING=ON \
      -DCMAKE_EXE_LINKER_FLAGS="-static" \
      -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
      -DCMAKE_C_FLAGS="-static" \
      -DCMAKE_CXX_FLAGS="-static" \
      -DCMAKE_SHARED_LINKER_FLAGS="-static"

make -C "$BUILD_DIR" -j$(nproc)

# Basic smoke test
./"$BUILD_DIR"/src/bpftrace --help

# Validate that it's a mostly static binary except for libc
# EXPECTED="Not a valid dynamic program"
# GOT=$(ldd "$BUILD_DIR"/src/bpftrace 2>&1)

# if [[ "$GOT" == *"$EXPECTED"* ]]; then
#   echo "bpftrace is correctly statically linked"
# else
#   set +x
#   >&2 echo "bpftrace incorrectly linked"
#   exit 1
# fi
