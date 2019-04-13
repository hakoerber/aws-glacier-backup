#!/usr/bin/env bash

source ./venv/bin/activate

set -o nounset
set -o errexit
set -o xtrace

bucket="${1}" ; shift
name="${1}" ; shift
backup_source="${1}" ; shift

cleanup() {
    rm -f ./keyring.tmp
    rm -f ./keyring.tmp~
}

trap cleanup EXIT

tmpgpg() {
    gpg \
        --batch \
        --keyring ./keyring.tmp \
        --no-default-keyring \
        --no-options \
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
    | aws s3 cp \
        --storage-class=DEEP_ARCHIVE \
        - \
        "s3://${bucket}/${name}-$(date --utc -Iseconds).tar.xz.gpg"
