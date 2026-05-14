# syntax=docker/dockerfile:1
#
# ha-libre-glucose-mqtt: Home Assistant Supervisor add-on wrapper around
# gluco-hub-rs.
#
# Strategy: copy the pre-built gluco-hub binary out of the upstream
# distroless image and lay it onto a HA-add-on Debian base (which ships
# bashio + s6-overlay). The base is glibc-based to match the binary,
# which is built against glibc in micschr0/gluco-hub-rs/Dockerfile.

# Tag the upstream gluco-hub release used by this add-on. Bump this when
# bumping `version:` in config.yaml so the binary version actually
# matches the manifest.
ARG GLUCO_HUB_TAG=2026.514.0

# Pull the gluco-hub binary as a build context.
FROM ghcr.io/micschr0/gluco-hub:${GLUCO_HUB_TAG} AS upstream

# Provided by the HA Supervisor build system. See build.yaml for the
# per-arch mappings.
ARG BUILD_FROM
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

CMD ["/run.sh"]
