#!/usr/bin/env bash
set -euo pipefail

dockerfile="${1:-Dockerfile.payment-service}"
build_context="${2:-.}"
image_version="${IMAGE_VERSION:-1.0.0}"

if [[ ! -f "$dockerfile" ]]; then
  printf 'Dockerfile not found: %s\n' "$dockerfile" >&2
  printf 'Pass the payment-service Dockerfile path as the first argument.\n' >&2
  exit 2
fi

if [[ ! -d "$build_context" ]]; then
  printf 'Build context directory not found: %s\n' "$build_context" >&2
  exit 2
fi

read -r -p 'GitHub username: ' github_username
if [[ -z "$github_username" ]]; then
  printf 'GitHub username must not be empty.\n' >&2
  exit 2
fi

registry_owner="$(printf '%s' "$github_username" | tr '[:upper:]' '[:lower:]')"
image="ghcr.io/${registry_owner}/payment-service:${image_version}"

read -r -s -p 'GitHub classic PAT with write:packages: ' github_pat
printf '\n'
if [[ -z "$github_pat" ]]; then
  printf 'PAT must not be empty.\n' >&2
  exit 2
fi

if ! printf '%s' "$github_pat" | docker login ghcr.io --username "$github_username" --password-stdin; then
  unset github_pat
  exit 1
fi
unset github_pat

docker build --file "$dockerfile" --tag "$image" "$build_context"
docker push "$image"
printf 'Published %s\n' "$image"