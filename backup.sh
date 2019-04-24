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
backup_sources_file="${1}" ; shift
gpg_pubkey_file="${1}" ; shift
gpg_pubkey_id="${1}" ; shift

declare -a backup_sources
readarray backup_sources < "${backup_sources_file}"

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

for backup_dir in "${backup_sources[@]}" ; do
    backup_dir_expanded=($(eval "echo $backup_dir"))
    for dir in "${backup_dir_expanded[@]}" ; do
        echo $dir
        set -x
        find \
                "${dir[@]}" \
                \( \
                    -regex "${dir}.*/files_trashbin" \
                    -o \
                    -regex "${dir}.*nextcloud.log.*" \
                    -o \
                    -regex "${dir}.*registry/docker/registry" \
                    -o \
                    -regex "${dir}.*/gogs.log.*" \
                    -o \
                    -regex "${dir}.*gogs/data/sessions/.*" \
                    -o \
                    -regex "${dir}.*/cache/.*" \
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
                --force-local \
                --no-recursion \
                --files-from - \
                --file - \
            | gzip \
                --to-stdout \
            | tmpgpg \
                --output - \
                --encrypt \
                --recipient "${gpg_pubkey_id}" \
            | aws \
                s3 cp \
                - \
                "s3://${bucket}/${name}-${timestamp}/${dir##/}.tar.gz.gpg"
    done
done
