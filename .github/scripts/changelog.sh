#!/usr/bin/env bash

set -eu

COMMITS_TO_PUSH="$(git log --oneline origin..HEAD  | awk 'END { print NR }')"

if [ "$COMMITS_TO_PUSH" -ne "0" ]; then
    echo "COMMITS_TO_PUSH='$COMMITS_TO_PUSH' is not 0"
    exit 1
fi

if [ "$#" -ne 1 ]; then
    echo "Missing release version" >&2
    echo "$0 <release_version>" >&2
    exit 1
fi

if [ -z "$1" ]; then
    echo "CURRENT_VERSION='$CURRENT_VERSION' is empty" >&2
    exit 1
fi

CURRENT_VERSION="$1"
PREVIOUS_VERSION="$(git for-each-ref --format="%(refname)" --sort=creatordate --count=2 refs/tags | sort -r | head -n 1 | awk -F '/' '{print $3}')"


if [ -z "$PREVIOUS_VERSION" ]; then
    echo "PREVIOUS_VERSION='$PREVIOUS_VERSION' is empty" >&2
    exit 1
fi

RELEASE_CHANGELOG="$(mktemp)"

trap "rm -f $RELEASE_CHANGELOG" EXIT

echo -e "## Changes for cert-manager-webhook-ovh $CURRENT_VERSION\n" > "$RELEASE_CHANGELOG"

cat CHANGELOG.md | sed -n '/## v0.0.1-alpha1/,/## v0.0.1-alpha0/p;' | sed 'N;$!P;$!D;$d' | awk 'NR>2' >> "$RELEASE_CHANGELOG"

GH_OPTS=""
if [ ! -z "$(echo $CURRENT_VERSION | sed  '/-\(alpha\|beta\|rc\)/!d')" ]; then
    GH_OPTS="--prerelease"
fi

echo gh release create "$CURRENT_VERSION" --notes-file "$RELEASE_CHANGELOG" $GH_OPTS
