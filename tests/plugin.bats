#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"
load "${BATS_TEST_DIRNAME}/../lib/plugin.bash"
load "${BATS_TEST_DIRNAME}/../lib/shared.bash"

# export DOCKER_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup() {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="docker"
  export WIZ_CLIENT_ID="test"
  export WIZ_CLIENT_SECRET="secret"
  export WIZ_CLI_CONTAINER="public-registry.wiz.io/wiz-app/wizcli:1"
}

teardown() {
  if [ -d result ]; then
    rm -rf result
  fi

  # shellcheck disable=SC2144
  if [ -a *-annotation.md ]; then
    rm *-annotation.md
  fi

  if [ -a check-file ]; then
    rm check-file
  fi
}

@test "Validates Wiz Client Credentials" {
  run validate_wiz_client_credentials

  assert_success
}

@test "Invalid Wiz Client Credential (ID)" {
  export WIZ_CLIENT_ID=""

  run validate_wiz_client_credentials

  assert_failure
  assert_output "+++ 🚨 The following required environment variables are not set: WIZ_CLIENT_ID"
}

@test "Invalid Wiz Client Credentials (ID and Secret)" {
  export WIZ_CLIENT_ID=""
  export WIZ_CLIENT_SECRET=""

  run validate_wiz_client_credentials

  assert_failure
  assert_output "+++ 🚨 The following required environment variables are not set: WIZ_CLIENT_ID WIZ_CLIENT_SECRET"
}

@test "Invalid Scan Format" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT="wrong-format"

  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_failure
  assert_output --partial "+++ 🚨 Invalid Scan Format: $BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT"
}

@test "Invalid File Output Format" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT="wrong-format"

  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_failure
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT"
}

@test "Invalid File Output Format (multiple)" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="wrong-format"

  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_failure
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"
}

@test "Duplicate File Output Formats" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="human"

  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_success
  assert_output --partial "+++ ⚠️  Duplicate file output format ignored: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"
}

@test "Invalid File Output Format (multiple with duplicates)" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_2="wrong-format"

  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_failure
  assert_output --partial "+++ ⚠️  Duplicate file output format ignored: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_2"
}

@test "Valid Wiz CLI Args (default)" {
  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_success
  assert_output --partial "--stdout=human --human-output-file=/scan/result/output"
}

@test "Valid Wiz CLI Args (custom)" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT="json"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="json"

  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_success
  assert_output --partial "--stdout=json --human-output-file=/scan/result/output --human-output-file=/scan/result/output-human --json-output-file=/scan/result/output-json"
}

@test "Disable sensitive data scan adds --disabled-scanners" {
  export BUILDKITE_PLUGIN_WIZ_DISABLE_SENSITIVE_DATA_SCAN="true"

  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_success
  assert_output --partial "--disabled-scanners=SensitiveData"
}

@test "Sensitive data scan enabled by default (no --disabled-scanners)" {
  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_success
  refute_output --partial "--disabled-scanners"
}

@test "IaC type with dir scan type" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"
  export BUILDKITE_PLUGIN_WIZ_IAC_TYPE="Terraform"

  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_success
  assert_output --partial "--types=Terraform"
}

@test "Sarif and csv-zip file output formats" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="sarif"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="csv-zip"

  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_success
  assert_output --partial "--sarif-output-file=/scan/result/output-sarif"
  assert_output --partial "--csv-output-file=/scan/result/output-csv-zip"
}

@test "Parameter files with dir scan type" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"
  export BUILDKITE_PLUGIN_WIZ_PARAMETER_FILES="variables.tf"

  run build_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_success
  assert_output --partial "--parameter-files=variables.tf"
}

@test "Get Wiz CLI Container Image" {
  run detect_wiz_cli_container

  assert_success
  assert_output "public-registry.wiz.io/wiz-app/wizcli:1"
}

@test "Build Annotations for docker scan (no findings)" {

  run build_annotation "docker" "ubuntu:latest" true "result/output"

  assert_success

  assert_output --partial "<summary>Wiz Docker Image Scan for ubuntu:latest meets policy requirements.</summary>"
}

@test "Build Annotations for docker scan (findings)" {

  run build_annotation "docker" "ubuntu:latest" false "result/output"

  assert_success

  assert_output --partial "<summary>Wiz Docker Image Scan for ubuntu:latest does not meet policy requirements.</summary>"
}

@test "Build Annotations for iac scan" {

  run build_annotation "iac" "my-stack" true "result/output"

  assert_success

  assert_output --partial "<summary>Wiz IaC Scan for my-stack meets policy requirements.</summary>"
}

@test "Build Annotations for dir scan" {

  run build_annotation "dir" "my-dir" true "result/output"

  assert_success

  assert_output --partial "<summary>Wiz Directory Scan for my-dir meets policy requirements.</summary>"
}

@test "Docker Scan (success)" {
  export BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS="ubuntu:latest"
  export cli_args=("--stdout=human" "--human-output-file=/scan/result/output")

  mkdir -p "result"
  touch "result/output"

  stub docker \
    'pull "ubuntu:latest" : exit 0' \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock,readonly public-registry.wiz.io/wiz-app/wizcli:1 scan container-image ubuntu:latest --by-policy-hits=BLOCK --stdout=human --human-output-file=/scan/result/output : echo "Docker image scanned without policy hits"'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-docker-success' --style 'success' : echo "Annotated Build"'

  run docker_image_scan "${WIZ_CLI_CONTAINER}" "${BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS}" "${cli_args[@]}"

  assert_success

  assert_output --partial "Docker image scanned without policy hits"
  assert_output --partial "Annotated Build"

  unstub docker
  unstub buildkite-agent
}

@test "Docker Scan (failure)" {
  export BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS="ubuntu:latest"
  export cli_args=("--stdout=human" "--human-output-file=/scan/result/output")

  mkdir -p "result"
  touch "result/output"

  stub docker \
    'pull "ubuntu:latest" : exit 0' \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock,readonly public-registry.wiz.io/wiz-app/wizcli:1 scan container-image ubuntu:latest --by-policy-hits=BLOCK --stdout=human --human-output-file=/scan/result/output : echo "Docker image scanned with policy hits"; exit 1'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-docker-warning' --style 'warning' : echo "Annotated Build"'

  run docker_image_scan "${WIZ_CLI_CONTAINER}" "${BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS}" "${cli_args[@]}"

  assert_failure

  assert_output --partial "Docker image scanned with policy hits"
  assert_output --partial "Annotated Build"

  unstub docker
  unstub buildkite-agent
}

@test "IaC Scan (success)" {
  export BUILDKITE_JOB_ID="1234-abcd"
  export BUILDKITE_BUILD_ID="1234-abcd"
  export BUILDKITE_LABEL="iac-scan"
  export FILE_PATH="iac/to/scan"
  export cli_args=("--stdout=human" "--human-output-file=/scan/result/output")

  mkdir -p "result"
  touch "result/output"

  stub docker \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan public-registry.wiz.io/wiz-app/wizcli:1 scan dir /scan/iac/to/scan --name 1234-abcd --stdout=human --human-output-file=/scan/result/output : echo "IaC scanned without policy hits"'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-iac-success' --style 'success' : echo "Annotated Build"' \
    'artifact upload check-file : echo "Uploaded check-file"'

  run iac_scan "${WIZ_CLI_CONTAINER}" "${FILE_PATH}" "${cli_args[@]}"

  assert_success

  assert_output --partial "IaC scanned without policy hits"
  assert_output --partial "Annotated Build"
  assert_output --partial "Uploaded check-file"

  unstub docker
  unstub buildkite-agent
}

@test "IaC Scan (failure)" {
  export BUILDKITE_JOB_ID="1234-abcd"
  export BUILDKITE_BUILD_ID="1234-abcd"
  export BUILDKITE_LABEL="iac-scan"
  export FILE_PATH="iac/to/scan"
  export cli_args=("--stdout=human" "--human-output-file=/scan/result/output")

  mkdir -p "result"
  touch "result/output"

  stub docker \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan public-registry.wiz.io/wiz-app/wizcli:1 scan dir /scan/iac/to/scan --name 1234-abcd --stdout=human --human-output-file=/scan/result/output : echo "IaC scanned with policy hits"; exit 1'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-iac-warning' --style 'warning' : echo "Annotated Build"' \
    'artifact upload check-file : echo "Uploaded check-file"'

  run iac_scan "${WIZ_CLI_CONTAINER}" "${FILE_PATH}" "${cli_args[@]}"

  assert_failure

  assert_output --partial "IaC scanned with policy hits"
  assert_output --partial "Annotated Build"
  assert_output --partial "Uploaded check-file"

  unstub docker
  unstub buildkite-agent
}

@test "Directory Scan (success)" {
  export BUILDKITE_JOB_ID="1234-abcd"
  export BUILDKITE_BUILD_ID="1234-abcd"
  export BUILDKITE_LABEL="dir-scan"
  export FILE_PATH="dir/to/scan"
  export cli_args=("--stdout=human" "--human-output-file=/scan/result/output")

  mkdir -p "result"
  touch "result/output"

  stub docker \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan public-registry.wiz.io/wiz-app/wizcli:1 scan dir /scan/dir/to/scan --name 1234-abcd --stdout=human --human-output-file=/scan/result/output : echo "Directory scanned without policy hits"'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-dir-success' --style 'success' : echo "Annotated Build"' \
    'artifact upload check-file : echo "Uploaded check-file"'

  run dir_scan "${WIZ_CLI_CONTAINER}" "${FILE_PATH}" "${cli_args[@]}"

  assert_success

  assert_output --partial "Directory scanned without policy hits"
  assert_output --partial "Annotated Build"
  assert_output --partial "Uploaded check-file"

  unstub docker
  unstub buildkite-agent
}

@test "Directory Scan (failure)" {
  export BUILDKITE_JOB_ID="1234-abcd"
  export BUILDKITE_BUILD_ID="1234-abcd"
  export BUILDKITE_LABEL="dir-scan"
  export FILE_PATH="dir/to/scan"
  export cli_args=("--stdout=human" "--human-output-file=/scan/result/output")

  mkdir -p "result"
  touch "result/output"

  stub docker \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan public-registry.wiz.io/wiz-app/wizcli:1 scan dir /scan/dir/to/scan --name 1234-abcd --stdout=human --human-output-file=/scan/result/output : echo "Directory scanned with policy hits"; exit 1'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-dir-warning' --style 'warning' : echo "Annotated Build"' \
    'artifact upload check-file : echo "Uploaded check-file"'

  run dir_scan "${WIZ_CLI_CONTAINER}" "${FILE_PATH}" "${cli_args[@]}"

  assert_failure

  assert_output --partial "Directory scanned with policy hits"
  assert_output --partial "Annotated Build"
  assert_output --partial "Uploaded check-file"

  unstub docker
  unstub buildkite-agent
}
