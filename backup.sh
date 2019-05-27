#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o xtrace

shopt -s extglob

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ ! -e "${dir}/venv" ]] ; then
    python3 -m venv "${dir}/venv"
fi
source "${dir}/venv/bin/activate"
command -v aws || pip install -r "${dir}/requirements.txt"

export GNUPGHOME="$(mktemp -d)"

bucket="${1}" ; shift
name="${1}" ; shift
filelist_script="${1}" ; shift
gpg_pubkey_file="${1}" ; shift
gpg_pubkey_id="${1}" ; shift

install --directory --owner $(id -u) --group $(id -g) --mode 700 "${GNUPGHOME}"

cleanup() {
    rm -rf "${GNUPGHOME}"
}

trap cleanup EXIT

tmpgpg() {
    gpg \
        --batch \
        --keyid-format=0xlong \
        --no-default-keyring \
        --no-options \
        --trust-model always \
        "${@}"
}

tmpgpg --import "${gpg_pubkey_file}"
tmpgpg -k

timestamp="$(date --utc -Iseconds)"

"${filelist_script}" | while read filelist ; do
    filepath="$(echo "$filelist" | cut -d ':' -f 1)"
    fifo="$(echo "$filelist" | cut -d ':' -f 2)"
    mkdir -p "$(dirname "${filepath}")"
    echo "$fifo"
    <"$fifo" tar \
        --create \
        --verbose \
        --no-auto-compress \
        --ignore-failed-read \
        --acls \
        --selinux \
        --xattrs \
        --null \
        --force-local \
        --no-recursion \
        --files-from - \
        --file - \
    | gzip \
        --to-stdout \
    | tmpgpg \
        --output - \
        --encrypt \
        --compress-algo none \
        --cipher-algo AES256 \
        --digest-algo SHA256 \
        --recipient "${gpg_pubkey_id}" \
    | aws \
        s3 cp \
        --storage-class DEEP_ARCHIVE \
        # specify max object size of 5TB here. This makes aws-cli use a bigger
        # chunk size for the multipart upload. Otherwise, objects >5GB cannot
        # be uploaded because the max chunk count is 1e4
        #
        # It's very hacky because it makes uploads of small files more
        # inefficient
        --expected-size=$(5*1000*1000*1000) \
        - \
        "s3://${bucket}/${name}-${timestamp}/${filepath##+(/)}.tar.gz.gpg"
done
