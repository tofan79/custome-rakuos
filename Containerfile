# RakuOS KineticWE Image
ARG BASE_IMAGE_TAG="${BASE_IMAGE_TAG:-staging}"
ARG BASE_IMAGE_REPO="quay.io/rakuos/rakuos-base-nvidia-v3"
ARG RAKUOS_STAGING="0"

FROM ${BASE_IMAGE_REPO}:${BASE_IMAGE_TAG}
ENV BASE_IMAGE_TAG=${BASE_IMAGE_TAG}
ENV RAKUOS_STAGING=${RAKUOS_STAGING}

COPY build_files /
COPY system_files /

# Cache-bust: refresh KineticWE and related packages on every
# build even when no repo files changed. Set via workflow BUILD_DATE arg.
ARG BUILD_DATE=""
ENV BUILD_DATE=${BUILD_DATE}

RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /build.sh && /post-build.sh && /post-build-overlay.sh

# Clean up real runtime state (systemd units started mid-build, akmods/
# cryptsetup/etc. lock and socket files) that only ever makes sense on a
# live booted system. Same step rakuos-base runs on its own image.
# This runs as its own RUN, after every mounted (--mount=type=secret/
# cache/tmpfs) build step above has already finished and unmounted, so it
# only ever touches plain files already baked into the layer — never a
# live mount the build engine itself still has open.
RUN find /run -mindepth 1 -delete 2>/dev/null || true; \
    find /tmp -mindepth 1 -delete 2>/dev/null || true; \
    find /boot -mindepth 1 -delete 2>/dev/null || true
