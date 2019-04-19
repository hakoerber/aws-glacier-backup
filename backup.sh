#!/usr/bin/env bash

set -o nounset
set -o errexit
# set -o xtrace

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

tmpgpg --import "${dir}/pubkey.asc"
tmpgpg -k

timestamp="$(date --utc -Iseconds)"

while read -r line ; do
    echo $line
done < <("${dir}/filelist.py" "${backup_sources_file}")
exit 1

for backup_dir in "${backup_sources[@]}" ; do
    backup_dir_expanded=($(eval "echo $backup_dir"))
    for backup_dir in "${backup_backup_dir_expanded[@]}" ; do
        continue
        echo $backup_dir
        set -x
        find \
                "${backup_dir[@]}" \
                \( \
                    -regex "${backup_dir}.*/files_trashbin" \
                    -o \
                    -regex "${backup_dir}.*nextcloud.log.*" \
                    -o \
                    -regex "${backup_dir}.*registry/docker/registry" \
                    -o \
                    -regex "${backup_dir}.*/gogs.log.*" \
                    -o \
                    -regex "${backup_dir}.*gogs/data/sessions/.*" \
                    -o \
                    -regex "${backup_dir}.*/cache/.*" \
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
                --recipient 0x078A167A8741BD30 \
            | aws \
                s3 cp \
                - \
                "s3://${bucket}/${name}-${timestamp}/${backup_dir##/}.tar.gz.gpg"
    done
done
