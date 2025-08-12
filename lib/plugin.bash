#!/bin/bash

# Determine the machine architecture to select the appropriate container image tag.
# Available images: `latest`, `latest-amd64`, and `latest-arm64`.
# For x86_64 and arm64/aarch64, use the corresponding tag; for unknown architectures, fallback to the default `latest` tag.
function get_wiz_cli_container() {
    local architecture
    architecture=$(uname -m)
    local container_image_tag="latest"

    case $architecture in
    x86_64)
        container_image_tag+="-amd64"
        ;;
    arm64 | aarch64)
        container_image_tag+="-arm64"
        ;;
    *) ;;
    esac

    wiz_cli_container_repository="wiziocli.azurecr.io/wizcli"
    echo "${wiz_cli_container_repository}:${container_image_tag}"
}

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

dockerImageScan() {
    local wiz_cli_container_image="$1"

    mkdir -p result
    # TODO check feasibility of mount/mountWithLayers
    IMAGE="${BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS:-}"
    # make sure local docker has the image
    docker pull "$IMAGE"
    docker run \
        --rm -it \
        --mount type=bind,src="$WIZ_DIR",dst=/cli,readonly \
        --mount type=bind,src="$PWD",dst=/scan \
        --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock,readonly \
        "${wiz_cli_container_image}" \
        docker scan --image "$IMAGE" \
        --policy-hits-only \
        ${args:+"${args[@]}"}

    exit_code="$?"
    image_name=$(echo "$IMAGE" | cut -d "/" -f 2)
    # FIXME: Linktree Specific Env. Var.
    # buildkite-agent artifact upload result --log-level info
    case $exit_code in
    0)
        buildAnnotation "docker" "$image_name" true "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-docker-success' --style 'success'
        ;;
    *)
        buildAnnotation "docker" "$image_name" false "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-docker-warning' --style 'warning'
        ;;
    esac
    exit $exit_code
}

iacScan() {
    local wiz_cli_container_image="$1"

    mkdir -p result
    docker run \
        --rm -it \
        --mount type=bind,src="$WIZ_DIR",dst=/cli,readonly \
        --mount type=bind,src="$PWD",dst=/scan \
        "${wiz_cli_container_image}" \
        iac scan \
        --name "$BUILDKITE_JOB_ID" \
        --path "/scan/$FILE_PATH" ${args:+"${args[@]}"}

    exit_code="$?"
    case $exit_code in
    0)
        buildAnnotation "iac" "$BUILDKITE_LABEL" true "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-iac-success' --style 'success'
        ;;
    *)
        buildAnnotation "iac" "$BUILDKITE_LABEL" false "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-iac-warning' --style 'warning'
        ;;
    esac
    # buildkite-agent artifact upload "result/**/*" --log-level info
    # this post step will be used in template to check the step was run
    echo "${BUILDKITE_BUILD_ID}" >check-file && buildkite-agent artifact upload check-file

    exit $exit_code
}

dirScan() {
    local wiz_cli_container_image="$1"

    mkdir -p result
    docker run \
        --rm -it \
        --mount type=bind,src="$WIZ_DIR",dst=/cli,readonly \
        --mount type=bind,src="$PWD",dst=/scan \
        "${wiz_cli_container_image}" \
        dir scan \
        --name "$BUILDKITE_JOB_ID" \
        --path "/scan/$FILE_PATH" ${args:+"${args[@]}"}

    exit_code="$?"
    case $exit_code in
    0)
        buildAnnotation "dir" "$BUILDKITE_LABEL" true "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-dir-success' --style 'success'
        ;;
    *)
        buildAnnotation "dir" "$BUILDKITE_LABEL" false "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-dir-warning' --style 'warning'
        ;;
    esac
    # buildkite-agent artifact upload "result/**/*" --log-level info
    # this post step will be used in template to check the step was run
    echo "${BUILDKITE_BUILD_ID}" >check-file && buildkite-agent artifact upload check-file

    exit $exit_code
} 