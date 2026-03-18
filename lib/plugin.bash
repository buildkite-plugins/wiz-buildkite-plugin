#!/usr/bin/env bash

set -euo pipefail

# Build CLI arguments for v1 scan commands.
# $1 - Scan Type
function build_wiz_cli_args() {
    local scan_type="${1}"

    local parameter_files="${BUILDKITE_PLUGIN_WIZ_PARAMETER_FILES:-}"
    local iac_type="${BUILDKITE_PLUGIN_WIZ_IAC_TYPE:-}"
    local scan_format="${BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT:-human}"
    local disable_sensitive_data_scan="${BUILDKITE_PLUGIN_WIZ_DISABLE_SENSITIVE_DATA_SCAN:-false}"
    local -a args=()

    if [[ "${disable_sensitive_data_scan}" == "true" ]]; then
        args+=("--disabled-scanners=SensitiveData")
    fi

    local scan_formats=("human" "json" "sarif")
    if in_array "$scan_format" "${scan_formats[@]}"; then
        args+=("--stdout=${scan_format}")
    else
        echo "+++ 🚨 Invalid Scan Format: ${scan_format}" >&2
        echo "Valid Formats: ${scan_formats[*]}" >&2
        exit 1
    fi

    # Define valid formats
    local valid_file_formats=("human" "json" "sarif" "csv-zip")

    # Default file output used for build annotation
    args+=("--human-output-file=/scan/result/output")

    local -a result=()

    if plugin_read_list_into_result "BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT"; then
        local -A seen_formats=()
        for format in "${result[@]}"; do
            if [[ -n "${seen_formats[$format]:-}" ]]; then
                echo "+++ ⚠️  Duplicate file output format ignored: ${format}"
                continue
            fi
            seen_formats["$format"]=1

            if in_array "$format" "${valid_file_formats[@]}"; then
                local flag_prefix="${format}"
                if [[ "${format}" == "csv-zip" ]]; then
                    flag_prefix="csv"
                fi
                args+=("--${flag_prefix}-output-file=/scan/result/output-${format}")
            else
                echo "+++ 🚨 Invalid File Output Format: ${format}" >&2
                echo "Valid Formats: ${valid_file_formats[*]}" >&2
                exit 1
            fi
        done
    fi

    # IaC-specific parameters apply to both iac and dir scan types
    if [[ "${scan_type}" == "iac" || "${scan_type}" == "dir" ]]; then
        if [[ -n "${iac_type}" ]]; then
            args+=("--types=${iac_type}")
        fi

        if [[ -n "${parameter_files}" ]]; then
            args+=("--parameter-files=${parameter_files}")
        fi
    fi

    echo "${args[*]}"
}

# Return the v1 Wiz CLI container image reference.
# The v1 image is multi-arch, so no architecture-specific tags are needed.
function detect_wiz_cli_container() {
    echo "public-registry.wiz.io/wiz-app/wizcli:1"
}

function validate_wiz_client_credentials() {
    local missing_vars=()

    [ -z "${WIZ_CLIENT_ID:-}" ] && missing_vars+=("WIZ_CLIENT_ID")
    [ -z "${WIZ_CLIENT_SECRET:-}" ] && missing_vars+=("WIZ_CLIENT_SECRET")

    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "+++ 🚨 The following required environment variables are not set: ${missing_vars[*]}" >&2
        exit 1
    fi
}

# Create a Buildkite Annotation from scan results.
# $1 - scan type
# $2 - scan name
# $3 - scan pass/fail
# $4 - scan result file
function build_annotation() {
    local annotation_file="${RANDOM:0:2}-annotation.md"
    local scan_label
    case "$1" in
        docker) scan_label="Wiz Docker Image Scan" ;;
        iac)    scan_label="Wiz IaC Scan" ;;
        dir)    scan_label="Wiz Directory Scan" ;;
        *)      scan_label="Wiz Scan" ;;
    esac
    local pass_or_fail
    pass_or_fail=$(if [ "$3" = "true" ]; then echo 'meets'; else echo 'does not meet'; fi)
    local summary="${scan_label} for ${2} ${pass_or_fail} policy requirements"
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

# Container Image Scan using WizCLI v1 'scan container-image' command.
# v1 authenticates inline via WIZ_CLIENT_ID/WIZ_CLIENT_SECRET env vars.
# $1 - Wiz CLI Container Image
# $2 - Image Address
# $3+ - CLI Arguments
function docker_image_scan() {
    local wiz_cli_container_image="${1:-}"
    local image="${2:-}"
    shift 2
    local -a cli_args=("${@}")

    mkdir -p result

    docker pull "$image"

    local -i exit_code=0
    docker run \
        --rm \
        -e WIZ_CLIENT_ID \
        -e WIZ_CLIENT_SECRET \
        --mount type=bind,src="$PWD",dst=/scan \
        --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock,readonly \
        "${wiz_cli_container_image}" \
        scan container-image "$image" \
        "${cli_args[@]}" || exit_code=$?

    local image_name
    image_name="${image##*/}"

    if [[ $exit_code -eq 0 ]]; then
        build_annotation "docker" "$image_name" true "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-docker-success' --style 'success'
    else
        build_annotation "docker" "$image_name" false "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-docker-warning' --style 'warning'
    fi

    exit $exit_code
}

# IaC Scan — routes to v1 'scan dir' with IaC-specific flags.
# $1 - Wiz CLI Container Image
# $2 - File Path
# $3+ - CLI Arguments
function iac_scan() {
    local wiz_cli_container_image="${1:-}"
    local file_path="${2:-}"
    shift 2
    local -a cli_args=("${@}")

    mkdir -p result

    local -i exit_code=0
    docker run \
        --rm \
        -e WIZ_CLIENT_ID \
        -e WIZ_CLIENT_SECRET \
        --mount type=bind,src="$PWD",dst=/scan \
        "${wiz_cli_container_image}" \
        scan dir "/scan/$file_path" \
        --name "$BUILDKITE_JOB_ID" \
        "${cli_args[@]}" || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        build_annotation "iac" "$BUILDKITE_LABEL" true "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-iac-success' --style 'success'
    else
        build_annotation "iac" "$BUILDKITE_LABEL" false "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-iac-warning' --style 'warning'
    fi

    echo "${BUILDKITE_BUILD_ID}" >check-file && buildkite-agent artifact upload check-file

    exit $exit_code
}

# Directory Scan using WizCLI v1 'scan dir' command.
# $1 - Wiz CLI Container Image
# $2 - File Path
# $3+ - CLI Arguments
function dir_scan() {
    local wiz_cli_container_image="${1:-}"
    local file_path="${2:-}"
    shift 2
    local -a cli_args=("${@}")

    mkdir -p result

    local -i exit_code=0
    docker run \
        --rm \
        -e WIZ_CLIENT_ID \
        -e WIZ_CLIENT_SECRET \
        --mount type=bind,src="$PWD",dst=/scan \
        "${wiz_cli_container_image}" \
        scan dir "/scan/$file_path" \
        --name "$BUILDKITE_JOB_ID" \
        "${cli_args[@]}" || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        build_annotation "dir" "$BUILDKITE_LABEL" true "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-dir-success' --style 'success'
    else
        build_annotation "dir" "$BUILDKITE_LABEL" false "result/output" | buildkite-agent annotate --append --context 'ctx-wiz-dir-warning' --style 'warning'
    fi

    echo "${BUILDKITE_BUILD_ID}" >check-file && buildkite-agent artifact upload check-file

    exit $exit_code
}
