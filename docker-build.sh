#!/bin/bash
PATH_PROJECT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
${PATH_PROJECT_DIR}/__run_as_docker.sh "${PATH_PROJECT_DIR}/build.sh" "$@"