#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o xtrace

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ ! -e "${dir}/venv" ]] ; then
    python3 -m venv "${dir}/venv"
fi
source "${dir}/venv/bin/activate"
command -v aws || pip install -r "${dir}/requirements.txt"

export GNUPGHOME="$(mktemp -d)"

bucket="${1}" ; shift
name="${1}" ; shift
backup_source="${1}" ; shift

install --directory --owner $(id -u) --group $(id -g) --mode 700 "${GNUPGHOME}"

cleanup() {
    rm -rf "${GNUPGHOME}"
}

trap cleanup EXIT

tmpgpg() {
    gpg \
        --batch \
        --no-default-keyring \
        --no-options \
        --trust-model always \
        "${@}"
}

tmpgpg --import "${dir}/pubkey.asc"
find \
        "${backup_source}" \
        \( \
            -regex "${backup_source}.*nextcloud/.*/files_trashbin" \
            -o \
            -regex "${backup_source}.*nextcloud/nextcloud.log" \
            -o \
            -regex "${backup_source}.*registry/docker/registry" \
            -o \
            -regex "${backup_source}.*gogs/.*/gogs.log.*" \
            -o \
            -regex "${backup_source}.*gogs/gogs/data/sessions/.*" \
            -o \
            -regex "${backup_source}.*/cache/.*" \
        \) \
        -prune \
        -o \
        -print0 \
    | tar \
        --create \
        --verbose \
        --no-auto-compress \
        --ignore-failed-read \
        --acls \
        --selinux \
        --xattrs \
        --null \
        --no-recursion \
        --files-from - \
        --file - \
    | gzip \
        --to-stdout \
    | tmpgpg \
        --output - \
        --encrypt \
        --recipient 0x078A167A8741BD30 \
    | aws \
        s3 cp \
        --storage-class=DEEP_ARCHIVE \
        - \
        "s3://${bucket}/${name}-$(date --utc -Iseconds).tar.gz.gpg"
