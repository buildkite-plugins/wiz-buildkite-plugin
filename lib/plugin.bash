#!/bin/bash

# Use WIZ_CLIENT_ID and WIZ_CLIENT_SECRET environment variables to authenticate to Wiz and get auth file
# $1 - Wiz CLI Container Image 
# $2 - Directory to store auth file
setupWiz() {
    local wiz_container_image="${1}"
    local wiz_dir="${2}"

    echo "Setting up and authenticating wiz"
    mkdir -p "$wiz_dir"
    docker run \
        --rm -it \
        --mount type=bind,src="${wiz_dir}",dst=/cli \
        -e WIZ_CLIENT_ID \
        -e WIZ_CLIENT_SECRET \
        "${wiz_container_image}" \
        auth
    # check that wiz-auth work expected, and a file in WIZ_DIR is created
    if [ -z "$(ls -A "${wiz_dir}")" ]; then
        echo "Wiz authentication failed, please confirm that credentials are set for WIZ_CLIENT_ID and WIZ_CLIENT_SECRET"
        exit 1
    else
        echo "Authenticated successfully"
    fi
}