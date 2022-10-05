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

if [ -d "charts" ]; then
    for D in charts/*; do
        echo -n "Linting Chart $D: "
        helm lint "$D" >/dev/null || exit 1
    done
fi

CURRENT_VERSION="$1"
PREVIOUS_VERSION="$(git for-each-ref --format="%(refname)" --sort=-creatordate --count=1 refs/tags | awk -F '/' '{print $3}')"

if git rev-parse "$CURRENT_VERSION" >/dev/null 2>&1; then
    echo "Release '$CURRENT_VERSION' already exists" >&2
    exit 1
fi

if [ -z "$PREVIOUS_VERSION" ]; then
    echo "PREVIOUS_VERSION='$PREVIOUS_VERSION' is empty" >&2
    exit 1
fi

if [ -z "$(cat CHANGELOG.md | grep "^## $CURRENT_VERSION")" ]; then
    echo "Cannot find '$CURRENT_VERSION' in CHANGELOG.md" >&2
    exit 1
fi

if [ -z "$(cat CHANGELOG.md | grep "^## $PREVIOUS_VERSION")" ]; then
    echo "Cannot find '$PREVIOUS_VERSION' in CHANGELOG.md" >&2
    exit 1
fi

RELEASE_CHANGELOG="$(mktemp)"

trap "rm -f $RELEASE_CHANGELOG" EXIT

echo -e "## Changes for cert-manager-webhook-ovh $CURRENT_VERSION\n" > "$RELEASE_CHANGELOG"

cat CHANGELOG.md | sed -n "/## $CURRENT_VERSION/,/## $PREVIOUS_VERSION/p;" | sed 'N;$!P;$!D;$d' | awk 'NR>2' | sed '/^$/d' >> "$RELEASE_CHANGELOG"
echo -n "- Released on " >> "$RELEASE_CHANGELOG"
TZ=UTC date >> "$RELEASE_CHANGELOG"

# we want to detect is a release name wasn't released but is now pulled into
# the release notes. If so, we should stop and request that unpublished release
# to be merge with the one we want to actually publish
cat "$RELEASE_CHANGELOG" | grep '^## ' | sed 's/^## //g;' | sed '1d' | while read R; do
    if [ -z "$(git tag -l | grep "$R")" ]; then
        echo "The release '$R' doesn't seem to have a tag and is showing up in CHANGELOG.md."
        echo "Most likely this release wasn't published and the changelog entries should be"
        echo "merged into '$CURRENT_VERSION'"
        exit 1
    fi
done

GH_OPTS=""
if [ ! -z "$(echo $CURRENT_VERSION | sed  '/-\(alpha\|beta\|rc\)/!d')" ]; then
    GH_OPTS="--prerelease"
fi

gh release create "$CURRENT_VERSION" --notes-file "$RELEASE_CHANGELOG" $GH_OPTS

sleep 2

git fetch -a
