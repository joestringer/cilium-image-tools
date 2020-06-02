#!/bin/bash

# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

MAKER_IMAGE="${MAKER_IMAGE:-docker.io/cilium/image-maker:bc81755ec8f6c5afcb10a416cef73f99a35fee2c}"

if [ "$#" -lt 6 ] ; then
  echo "$0 supports minimum 6 argument"
  exit 1
fi

root_dir="$(git rev-parse --show-toplevel)"

cd "${root_dir}"

image_name="${1}"
image_dir="${2}"

platform="${3}"
output="${4}"
builder="${5}"

shift 5

registries=("${@}")

image_tag="$("${root_dir}/scripts/make-image-tag.sh" "${image_dir}")"

tag_args=()
for registry in "${registries[@]}" ; do
  tag_args+=(--tag "${registry}/${image_name}:${image_tag}")
done

check_image_tag() {
  if [ -n "${MAKER_CONTAINER+x}" ] ; then
    crane digest "${1}" || (echo "error: crane returned $?" ; return 1)
  else
    # unlike with other utility scripts we don't want to self-re-exec inside the container, as native `docker buildx` is preferred
    docker run --env DOCKER_HUB_PUBLIC_ACCESS_ONLY=true --env QUAY_PUBLIC_ACCESS_ONLY=true --rm --volume "${root_dir}:/src" --workdir /src "${MAKER_IMAGE}" crane digest "${1}" || (echo "error: crane returned $?" ; return 1)
  fi
}

check_registries() {
  for registry in "${registries[@]}" ; do
    i="${registry}/${image_name}:${image_tag}"
    if ! check_image_tag "${i}" ; then
      echo "${i} doesn't exist"
      return 1
    fi
  done
}

do_build="${FORCE:-false}"

if [ "${do_build}" = "true" ] ; then
  echo "will force-build ${image_name}:${image_tag} without checking the registries"
fi

if [ "${do_build}" = "false" ] ; then
  case "${image_tag}" in
    *-dev)
      echo "will build ${image_name}:${image_tag} as it has dev suffix"
      do_build="true"
      ;;
    *-wip)
      echo "will build ${image_name}:${image_tag} as it has wip suffix"
      do_build="true"
      ;;
    *)
      if check_registries ; then
        echo "image ${image_name}:${image_tag} is already present in all of the registries"
        exit 0
      else
        echo "will build ${image_name}:${image_tag} as it's either a new version or not present in all of the registries"
        do_build="true"
      fi
      ;;
  esac
fi

run_buildx() {
  docker buildx build \
    "${tag_args[@]}" \
    --platform "${platform}" \
    --output "${output}" \
    --builder "${builder}" \
      "${image_dir}"
}

if [ "${do_build}" = "true" ] ; then
  echo "building ${image_name}:${image_tag}"
  set -o xtrace
  if ! run_buildx ; then
    if [ -n "${DEBUG+x}" ] ; then
      buildkitd_container="$(docker ps --filter "ancestor=moby/buildkit:buildx-stable-1" --filter "name=${builder}" --format "{{.ID}}")"
      docker logs "${buildkitd_container}"
    fi
    exit 1
  fi
fi