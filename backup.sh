#!/usr/bin/env bash

source ./venv/bin/activate

set -o nounset
set -o errexit

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
        "${1}" \
    | tmpgpg \
        --output - \
        --encrypt \
        --recipient hannes.koerber@haktec.de \
    | aws s3 cp \
        --storage-class=DEEP_ARCHIVE \
        - \
        s3://de-hkoerber-mycloud-backup/test.tar.xz.gpg
