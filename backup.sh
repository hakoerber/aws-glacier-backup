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
tar \
        --create \
        --verbose \
        --gzip \
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
        "s3://${bucket}/${name}-$(date --utc -Iseconds).tar.gz.gpg"
