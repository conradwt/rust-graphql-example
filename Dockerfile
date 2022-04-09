##
## Base
##

FROM rust:1.60.0-alpine3.14 as base

# labels from https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.authors=conradwt@gmail.com
LABEL org.opencontainers.image.created=$CREATED_DATE
LABEL org.opencontainers.image.revision=$SOURCE_COMMIT
LABEL org.opencontainers.image.title="Rust GraphQL Example"
LABEL org.opencontainers.image.url=https://hub.docker.com/u/conradwt/rust-graphql-example
LABEL org.opencontainers.image.source=https://github.com/conradwt/rust-graphql-example
LABEL org.opencontainers.image.licenses=MIT
LABEL com.conradtaylor.ruby_version=$RUST_VERSION

# set this with shell variables at build-time.
# If they aren't set, then not-set will be default.
ARG CREATED_DATE=not-set
ARG SOURCE_COMMIT=not-set

# environment variables
ENV APP_PATH /app
# This is important, see https://github.com/rust-lang/docker-rust/issues/85
ENV RUSTFLAGS="-C target-feature=-crt-static"

# create application user.
# RUN addgroup --gid 1000 darnoc && \
#   adduser --uid 1000 --ingroup darnoc --shell /bin/bash --home darnoc

#
# https://pkgs.alpinelinux.org/packages?name=&branch=v3.14
#

# install build and runtime dependencies
RUN apk -U add --no-cache \
  libpq=13.6-r0 \
  musl-dev=1.2.2-r3 \
  postgresql-dev=13.6-r0 \
  rm -rf /var/cache/apk/* && \
  mkdir -p $APP_PATH

# RUN apk -U add --no-cache \
#   build-base=0.5-r2 \
#   bzip2=1.0.8-r1 \
#   ca-certificates=20211220-r0 \
#   curl=7.79.1-r0 \
#   fontconfig=2.13.1-r4 \
#   postgresql-dev=13.6-r0 \
#   tini=0.19.0-r0 \
#   tzdata=2022a-r0 && \
#   rm -rf /var/cache/apk/* && \
#   mkdir -p $APP_PATH

# set the workdir
WORKDIR $APP_PATH

# copy over your manifests
COPY ./Cargo.lock ./Cargo.lock
COPY ./Cargo.toml ./Cargo.toml

# copy your source tree
COPY ./src ./src

# this build step will cache your dependencies
RUN cargo build --release
RUN strip target/release/rust-graphql-example

##
## Production
##

FROM alpine:3.14.6

# environment variables
ENV APP_PATH /app

# install build and runtime dependencies
RUN apk -U add --no-cache \
  ca-certificates=20211220-r0 \
  curl=7.79.1-r0 \
  libgcc=10.3.1_git20210424-r2 \
  tini=0.19.0-r0 && \
  rm -rf /var/cache/apk/* && \
  mkdir -p $APP_PATH

# copy the build artifact from the build stage
COPY --from=base /app/target/release/rust-graphql-example .

HEALTHCHECK CMD curl http://127.0.0.1/ || exit 1

USER darnoc

ENTRYPOINT ["/sbin/tini", "--"]

# set the startup command to run your binary
CMD ["./rust-graphql-example"]
