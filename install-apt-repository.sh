#!/bin/bash

set -e

pgp_key_pair_name="DAS"
root_apt_repo_path="/var/www/html/apt-repo"
release_script="/usr/local/bin/generate-release.sh"
update_apt_repo_script="/usr/local/bin/update-apt-repo.sh"

setup_requirements() {
    echo "Installing requirements..."
    apt -y update

    apt -y install apache2 dpkg-dev curl
}

produce_release_files_update_script() {
    echo '#!/bin/sh
set -e

do_hash() {
    HASH_NAME=$1
    HASH_CMD=$2
    echo "${HASH_NAME}:"
    for f in $(find -type f); do
        f=$(echo $f | cut -c3-) # remove ./ prefix
        if [ "$f" = "Release" ]; then
            continue
        fi
        echo " $(${HASH_CMD} ${f}  | cut -d" " -f1) $(wc -c $f)"
    done
}

cat << EOF
Origin: DAS CLI Repository
Label: DAS
Suite: stable
Codename: stable
Version: 1.0
Architectures: amd64
Components: main
Description: This is an APT repository for installing the DAS command-line interface.
Date: $(date -Ru)
EOF
do_hash "MD5Sum" "md5sum"
do_hash "SHA1" "sha1sum"
do_hash "SHA256" "sha256sum"
' >$release_script

    chmod +x $release_script
}

setup_apt_repository() {
    mkdir -p $root_apt_repo_path/pool/main/das-cli
    mkdir -p $root_apt_repo_path/dists/stable/main/binary-amd64
    # mkdir -p $root_apt_repo_path/dists/stable/main/binary-i386

    produce_release_files_update_script
    produce_update_apt_repo_script
}

produce_update_apt_repo_script() {
    repo_hash_file=$(dirname $update_apt_repo_script)

    echo "#!/bin/sh
set -e

current_apt_repo_hash=\$(find $root_apt_repo_path -type f -exec sha256sum {} + | sha256sum
)

if [ -f $repo_hash_file/apt-repo-hash.txt ]; then
    apt_repo_hash=\$(cat $repo_hash_file)
    echo \"File with previous hash of the apt folder found\"
else
    apt_repo_hash=\$current_apt_repo_hash
    echo \"No file with previous directory hash found\"
fi

echo "PREVIOUS hash: ${apt_repo_hash}"
echo "CURRENT hash: ${current_apt_repo_hash}"

if [ \"\$apt_repo_hash\" != \"\$current_apt_repo_hash\" ]; then
    dpkg-scanpackages --arch amd64 $root_apt_repo_path/pool/ > $root_apt_repo_path/dists/stable/main/binary-amd64/Packages
    cat $root_apt_repo_path/dists/stable/main/binary-amd64/Packages | gzip -9 > $root_apt_repo_path/dists/stable/main/binary-amd64/Packages.gz

    cd $root_apt_repo_path/dists/stable

    $release_script > $root_apt_repo_path/dists/stable/Release

    cd $root_apt_repo_path

    gpg --yes -abs -u $pgp_key_pair_name -o $root_apt_repo_path/dists/stable/Release.gpg $root_apt_repo_path/dists/stable/Release
    cat $root_apt_repo_path/dists/stable/Release | gpg --default-key $pgp_key_pair_name -abs --clearsign > $root_apt_repo_path/dists/stable/InRelease

    echo \$current_apt_repo_hash > $repo_hash_file
else
    echo \"No changes made in the repository\"
fi

" >$update_apt_repo_script

    chmod +x $update_apt_repo_script
}

setup_pgp_key_pair() {
    temp_dir=$(mktemp -d)
    pgp_key_batch="$temp_dir/pgp-key.batch"

    echo "%echo Generating an DAS PGP key
Key-Type: default
Key-Length: 4096
Name-Real: $pgp_key_pair_name
Name-Email: rafael.levi@singularitynet.io
Expire-Date: 0
%no-ask-passphrase
%no-protection
%commit" >$pgp_key_batch

    gpg --no-tty --batch --gen-key $pgp_key_batch
    gpg --export $pgp_key_pair_name >$root_apt_repo_path/das-cli.gpg
}

produce_user_installer() {
    public_ip_address=$(curl ifconfig.me)
    installer_script="$root_apt_repo_path/get.sh"

    echo "#!/bin/sh
set -e
echo \"Setting apt repository...\"
echo \"deb [arch=amd64] http://$public_ip_address/apt-repo stable main\" | tee /etc/apt/sources.list.d/dascli.list
echo \"Setting public key...\"
wget --no-verbose --force-directories http://$public_ip_address/apt-repo/das-cli.gpg -O /etc/apt/trusted.gpg.d/das-cli.gpg
echo \"Updating repositories...\"
apt update
echo \"Done.\"
" >$installer_script

    chmod +x $installer_script

}

setup_requirements
setup_apt_repository
setup_pgp_key_pair
produce_user_installer
