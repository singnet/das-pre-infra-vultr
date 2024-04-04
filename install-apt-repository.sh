#!/bin/bash

set -e

pgp_key_pair_name="DAS"
root_apt_repo_path="/var/www/html/apt-repo"
release_script="/usr/local/bin/generate-release.sh"
update_apt_repo_script="/usr/local/bin/update-apt-repo.sh"

setup_requirements() {
    echo "Installing requirements..."
    apt -y update

    apt -y install apache2 dpkg-dev curl ufw

    rm /var/www/html/index.html

    ufw enable
    ufw allow http
}

configure_apt_repo_trigger() {
    local cron_job="*/5 * * * * /usr/local/bin/update-apt-repo.sh"

    echo "$cron_job" | sudo crontab -u root -

    echo "Cron job configured successfully."
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
    local repo_hash_file="$(dirname "$update_apt_repo_script")/apt-repo-hash.txt"

    cat <<EOF >"$update_apt_repo_script"
#!/bin/sh

set -e

calculate_hash() {
    find "\$1" -type f -exec sha256sum {} + | sha256sum | awk '{gsub(/^ +| +$/,"")} {print \$1}'
}

update_repository() {
    cd "\$1"

    dpkg-scanpackages --multiversion --arch amd64 pool/ > dists/stable/main/binary-amd64/Packages
    cat dists/stable/main/binary-amd64/Packages | gzip -9 > dists/stable/main/binary-amd64/Packages.gz

    cd dists/stable

    "$release_script" > Release

    cd -

    gpg --yes -abs -u "$pgp_key_pair_name" -o "\$1/dists/stable/Release.gpg" "\$1/dists/stable/Release"
    gpg --default-key "$pgp_key_pair_name" -abs --clearsign < "\$1/dists/stable/Release" > "\$1/dists/stable/InRelease"
}

echo "Calculating hashes..."
current_apt_repo_hash=\$(calculate_hash "$root_apt_repo_path")

if [ -f "$repo_hash_file" ]; then
    apt_repo_hash=\$(cat "$repo_hash_file")
    echo "Previous hash file found."
else
    apt_repo_hash="$current_apt_repo_hash"
    echo "No previous hash file found."
fi

echo "Previous hash: \${apt_repo_hash}"
echo "Current hash: \${current_apt_repo_hash}"

if [ "\$apt_repo_hash" != "\$current_apt_repo_hash" ]; then
    echo "Updating repository..."
    update_repository "$root_apt_repo_path"
    calculate_hash "$root_apt_repo_path" > "$repo_hash_file"
    echo "Repository updated successfully."
else
    echo "No changes made in the repository."
fi
EOF

    chmod +x "$update_apt_repo_script"
}

setup_pgp_key_pair() {
    local temp_dir=$(mktemp -d)
    local pgp_key_batch="$temp_dir/pgp-key.batch"

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

produce_das_cli_setup_script() {
    local public_ip_address=$(curl ifconfig.me)
    local installer_script="$root_apt_repo_path/setup.sh"

    cat <<EOF >$installer_script
#!/bin/bash

set -e

echo "Configuring apt repository..."
echo "deb [arch=amd64] http://$public_ip_address/apt-repo stable main" | sudo tee /etc/apt/sources.list.d/dascli.list

echo "Adding public key..."
wget --quiet --force-directories http://$public_ip_address/apt-repo/das-cli.gpg -O /etc/apt/trusted.gpg.d/das-cli.gpg

echo "Updating repositories..."
apt update

echo "Setup completed successfully."

EOF

    chmod +x $installer_script

}

setup_requirements
setup_apt_repository
setup_pgp_key_pair
produce_das_cli_setup_script
configure_apt_repo_trigger
