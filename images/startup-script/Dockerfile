# Copyright 2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

ARG ALPINE_BASE_IMAGE=docker.io/library/alpine:3.11@sha256:9a839e63dad54c3a6d1834e29692c8492d93f90c59c978c1ed79109ea4fb9a54

FROM ${ALPINE_BASE_IMAGE} as builder

RUN mkdir -p /out/etc/apk && cp -r /etc/apk/* /out/etc/apk/

RUN apk add --initdb --no-cache --root /out \
    bash \
    ca-certificates \
    util-linux \
    && true

COPY manage-startup-script.sh /out/usr/bin/manage-startup-script.sh

FROM scratch
COPY --from=builder /out /
CMD [ "/usr/bin/manage-startup-script.sh" ]
