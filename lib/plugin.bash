#!/bin/bash

function validateWizClientCredentials() {
    local missing_vars=()
    
    [ -z "${WIZ_CLIENT_ID}" ] && missing_vars+=("WIZ_CLIENT_ID")
    [ -z "${WIZ_CLIENT_SECRET}" ] && missing_vars+=("WIZ_CLIENT_SECRET")
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "+++ 🚨 The following required environment variables are not set: ${missing_vars[*]}"
        exit 1
    fi
}

# Use WIZ_CLIENT_ID and WIZ_CLIENT_SECRET environment variables to authenticate to Wiz and get auth file
# $1 - Wiz CLI Container Image 
# $2 - Directory to store auth file
function setupWiz() {
    local wiz_container_image="${1}"
    local wiz_dir="${2}"

    echo "Setting up and authenticating wiz"
    validateWizClientCredentials
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
        echo "Wiz authentication failed, please confirm the credentials are set for WIZ_CLIENT_ID and WIZ_CLIENT_SECRET"
        exit 1
    else
        echo "Authenticated successfully"
    fi
}

# Create a Buildkite Annotation from a scan results
# $1 - scan type
# $2 - scan name
# $3 - scan pass/fail
# $4 - scan result file
buildAnnotation() {
    annotation_file=${RANDOM:0:2}-annotation.md
    docker_or_iac=$(if [ "$1" = "docker" ]; then echo "Wiz Docker Image Scan"; else echo "Wiz IaC Scan"; fi)
    pass_or_fail=$(if [ "$3" = "true" ]; then echo 'meets'; else echo 'does not meet'; fi)
    summary="${docker_or_iac} for ${2} ${pass_or_fail} policy requirements"
    # we need to create a new file to avoid conflicts, we need scan type, name, pass/fail
    cat <<EOF >>./"${annotation_file}"
<details>
<summary>$summary.</summary>

\`\`\`term
$(cat "$4")
\`\`\`

</details>
EOF
    printf "%b\n" "$(cat ./"${annotation_file}")"
}