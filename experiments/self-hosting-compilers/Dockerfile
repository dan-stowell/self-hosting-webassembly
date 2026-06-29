# Reproducibility proof: build the compiler suite to wasm from a clean base.
#
#   docker build -t self-hosting-wasm .
#
# The build runs scripts/verify.sh as a step, so a successful image build means
# every "builds-to-wasm" compiler was built from its vendored source and passed
# its smoke test under a from-source wasm3 runtime — on a clean machine with only
# the apt toolchain below.
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
      gcc libc6-dev make llvm wabt libuv1-dev golang-go git ca-certificates file \
    && rm -rf /var/lib/apt/lists/*

# The copied tree is a git repo; don't stamp VCS info into Go builds.
ENV GOFLAGS=-buildvcs=false

WORKDIR /work
COPY . .

# Build the wasm3 WASI runtime from source, then build every compiler to wasm
# and verify each. Build fails if any compiler fails to build or run.
RUN scripts/build-wasm3.sh && scripts/verify.sh

CMD ["scripts/verify.sh"]
