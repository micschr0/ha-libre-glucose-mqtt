# syntax=docker/dockerfile:1
#
# libre-glucose: Home Assistant Supervisor app (formerly add-on)
# wrapper around gluco-hub-rs.
#
# Strategy: copy the pre-built gluco-hub binary out of the upstream
# distroless image and lay it onto a HA-app Debian base (which ships
# bashio + s6-overlay). The base is glibc-based to match the binary,
# which is built against glibc in micschr0/gluco-hub-rs/Dockerfile.

# Tag the upstream gluco-hub release used by this app. Bump this in
# lockstep with `version:` in config.yaml so the binary version always
# names the release it bundles. Renovate's customManagers keep this in
# sync with build.yaml + config.yaml automatically.
ARG GLUCO_HUB_TAG=2026.516.2

# `BUILD_FROM` must be a GLOBAL ARG (declared before any FROM) so it
# remains in scope at the final `FROM ${BUILD_FROM}` line. Declaring it
# after the first FROM scopes it to the upstream stage only and leaves
# the variable unresolved below.
ARG BUILD_FROM

# Pull the gluco-hub binary as a build context.
FROM ghcr.io/micschr0/gluco-hub:${GLUCO_HUB_TAG} AS upstream

# BUILD_FROM is supplied by the HA Supervisor build system; see
# build.yaml for per-arch mappings. The tag IS pinned upstream via
# that mapping, just not visible to hadolint here.
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# The gluco-hub binary is a fully static-ish glibc executable; it does
# not need any runtime libraries beyond what the HA Debian base ships.
COPY --from=upstream /usr/local/bin/gluco-hub /usr/local/bin/gluco-hub

# Entrypoint.
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Standard add-on labels — fed by the Supervisor at build time.
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.revision="${BUILD_REF}" \
    org.opencontainers.image.version="${BUILD_VERSION}" \
    org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.licenses="AGPL-3.0-or-later"

# Liveness probe — replaces the deprecated Supervisor `watchdog:` field.
# Tests the gluco-hub HTTP listener (bound to 0.0.0.0:8080 in run.sh).
# `bash` is provided by the HA Debian base image; `/dev/tcp` is bash's
# built-in virtual-FS for TCP connect, so no extra packages are needed.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD bash -c '</dev/tcp/127.0.0.1/8080' || exit 1

CMD ["/run.sh"]
