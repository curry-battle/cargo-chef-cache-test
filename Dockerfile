# syntax=docker/dockerfile:1
ARG CARGO_LAMBDA_VERSION=1.7.0
ARG CARGO_CHEF_VERSION=0.1.73
ARG SCCACHE_VERSION=0.12.0
ARG MOLD_VERSION=2.40.4
ARG SCCACHE_DIR=/sccache

# 0: Rust + cargo-lambda + cargo-chef + sccache + mold イメージ
FROM ghcr.io/cargo-lambda/cargo-lambda:${CARGO_LAMBDA_VERSION} AS base
ARG CARGO_CHEF_VERSION
ARG SCCACHE_VERSION
ARG MOLD_VERSION
ARG SCCACHE_DIR

RUN cargo install cargo-chef --version ${CARGO_CHEF_VERSION} --locked

RUN ARCH=$(uname -m) \
 && curl -L https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/sccache-v${SCCACHE_VERSION}-${ARCH}-unknown-linux-musl.tar.gz \
 | tar xz \
 && cp sccache-*/sccache /usr/local/bin/ \
 && rm -rf sccache-*

RUN ARCH=$(uname -m) \
 && curl -L https://github.com/rui314/mold/releases/download/v${MOLD_VERSION}/mold-${MOLD_VERSION}-${ARCH}-linux.tar.gz \
 | tar xz \
 && cp mold-*/bin/* /usr/local/bin/ \
 && rm -rf mold-*

ENV RUSTC_WRAPPER=sccache \
    SCCACHE_DIR=${SCCACHE_DIR} \
    CARGO_INCREMENTAL=0 \
    RUSTFLAGS="-C link-arg=-fuse-ld=mold"


# 1: Planning - cargo-chefでrecipe.jsonを作る
FROM base AS planner
WORKDIR /build
COPY lambda /build/lambda
RUN cd /build/lambda && cargo chef prepare --recipe-path /build/recipe.json

# 2: Building - 依存関係をキャッシュ
FROM base AS builder
ARG SCCACHE_DIR

WORKDIR /build/lambda
COPY --from=planner /build/recipe.json recipe.json

# 依存関係のビルド
# sccacheキャッシュをマウントして、cargo chef cookで依存関係をビルド
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,target=/sccache,sharing=locked \
    (cargo chef cook --release --target x86_64-unknown-linux-gnu --recipe-path recipe.json || true) && \
    sccache --show-stats

# アプリケーションのビルド
COPY lambda /build/lambda

# アプリケーションのみをビルド（依存関係は既にビルド済み）
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,target=/sccache,sharing=locked \
    cargo lambda build --release --compiler cargo && \
    sccache --show-stats