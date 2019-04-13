#!/usr/bin/env bash

source ./venv/bin/activate

set -o nounset
set -o errexit

_GPG_HOMEDIR=./gpg-homedir.tmp

mkdir -p "${_GPG_HOMEDIR}"
chmod 700 "${_GPG_HOMEDIR}"
cleanup() {
    rm -rf "${_GPG_HOMEDIR}"
}

trap cleanup EXIT

tmpgpg() {
    gpg \
        --batch \
        --homedir "${_GPG_HOMEDIR}" \
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
