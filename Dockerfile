##
## Base
##

FROM rust:1.61.0-alpine3.15 as base

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

#
# https://pkgs.alpinelinux.org/packages?name=&branch=v3.15
#

# install build and runtime dependencies
RUN apk -U add --no-cache \
  libpq=14.3-r0 \
  musl-dev=1.2.2-r7 \
  postgresql14-dev=14.3-r0 \
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
WORKDIR ${APP_PATH}

RUN USER=root cargo init --bin

# build diesel first as there may be no changes and caching will be used
RUN echo "building diesel-cli" && \
  cargo install diesel_cli --root ${APP_PATH} --bin diesel --force --no-default-features --features postgres

# copy over your manifests
COPY ./Cargo.lock ./Cargo.lock
COPY ./Cargo.toml ./Cargo.toml

# this build step will cache your dependencies
RUN cargo build --release
RUN rm -rf ./src ./target/release/deps/rust-graphql-example*

# copy your source tree
COPY ./src ./src

# build the release
RUN cargo build --release

# https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/CompilerOptions.html
# RUN strip target/release/rust-graphql-example

##
## Production
##

FROM alpine:3.15.4

# environment variables
ENV APP_PATH /app

# install build and runtime dependencies
RUN apk -U add --no-cache \
  ca-certificates=20211220-r0 \
  curl=7.80.0-r1 \
  libgcc=10.3.1_git20211027-r0 \
  tini=0.19.0-r0 && \
  rm -rf /var/cache/apk/* && \
  mkdir -p $APP_PATH

# set the workdir
WORKDIR ${APP_PATH}

# https://perso.esiee.fr/~llorense/Labo5201/mc528x/PDFs/_read4-d5280.pdf
# create application user.
RUN addgroup --gid 1000 darnoc && \
  adduser --uid 1000 \
          --ingroup darnoc \
          --shell /bin/sh \
          --home ${APP_PATH} -D darnoc

# copy the build artifact from the build stage
COPY --from=base --chown=darnoc:darnoc /app/target/release/rust-graphql-example .
COPY --from=base --chown=darnoc:darnoc /app/bin/diesel .

# https://docs.docker.com/engine/reference/builder/#copy
# TODO copy binaries and migrations and set their user and group
COPY --chown=darnoc:darnoc ./migrations ${APP_PATH}/migrations

HEALTHCHECK CMD curl http://127.0.0.1/ || exit 1

USER darnoc

ENTRYPOINT ["/sbin/tini", "--"]

# set the startup command to run your binary
CMD ["/bin/sh", "-x", "-c", "/app/bin/diesel migration run && /app/bin/rust-graphql-example"]
