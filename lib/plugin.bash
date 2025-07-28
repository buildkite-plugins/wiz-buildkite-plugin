#!/bin/bash

setupWiz() {
    local wiz_container_image="${1}"
    local wiz_dir="${2}"

    echo "Setting up and authenticating wiz"
    mkdir -p "$wiz_dir"
    docker run \
        --rm -it \
        --mount type=bind,src="${wiz_dir}",dst=/cli \
        "${wiz_container_image}" \
        auth --id="${WIZ_API_ID}" --secret="${!api_secret_var}"
    # check that wiz-auth work expected, and a file in WIZ_DIR is created
    if [ -z "$(ls -A "${wiz_dir}")" ]; then
        echo "Wiz authentication failed, please confirm that credentials are set for WIZ_API_ID and WIZ_API_SECRET"
        exit 1
    else
        echo "Authenticated successfully"
    fi
}