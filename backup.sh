#!/usr/bin/env bash

source ./venv/bin/activate

set -o nounset
set -o errexit
set -o xtrace

export GNUPGHOME=./gpghome

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

tmpgpg --import ./pubkey.asc
tar \
        --create \
        --verbose \
        --xz \
        --one-file-system \
        --file - \
        "${backup_source}" \
    | tmpgpg \
        --output - \
        --encrypt \
        --recipient 0x078A167A8741BD30 \
    | aws \
        s3 cp \
        --storage-class=DEEP_ARCHIVE \
        - \
        "s3://${bucket}/${name}-$(date --utc -Iseconds).tar.xz.gpg"
