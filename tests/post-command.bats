#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"
load "${BATS_TEST_DIRNAME}/../lib/plugin.bash"

# Uncomment the following line to debug stub failures
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup() {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="docker"
  export BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS="ubuntu:22.04"
  export WIZ_DIR="$HOME/.wiz"
  export WIZ_CLIENT_ID="test"
  export WIZ_CLIENT_SECRET="secret"
  export WIZ_CLI_CONTAINER="wiziocli.azurecr.io/wizcli:latest"
}

teardown() {
  if [ -d "$WIZ_DIR" ]; then
    rm -rf "$WIZ_DIR"
  fi
}

@test "Captures docker exit code and exits plugin when non-0 status" {

  stub docker : 'exit 1'
  mkdir -p "$WIZ_DIR"
  touch "$WIZ_DIR/key"

  run "$PWD/hooks/post-command"
  #todo test docker scan
  assert_failure
}

@test "Validates Wiz Client Credentials" {

  run validateWizClientCredentials

  assert_success
}

@test "Invalid Wiz Client Credential (ID)" {
  unset WIZ_CLIENT_ID

  run validateWizClientCredentials

  assert_output "+++ 🚨 The following required environment variables are not set: WIZ_CLIENT_ID"
  assert_failure
}

@test "Invalid Wiz Client Credentials" {
  unset WIZ_CLIENT_ID
  unset WIZ_CLIENT_SECRET

  run validateWizClientCredentials

  assert_output "+++ 🚨 The following required environment variables are not set: WIZ_CLIENT_ID WIZ_CLIENT_SECRET"
  assert_failure
}

@test "Successfully authenticate to Wiz" {
  mkdir -p "$WIZ_DIR"
  touch "$WIZ_DIR/key"

  run setupWiz "$WIZ_CLI_CONTAINER" "$WIZ_DIR"

  assert_success
}

@test "Fail to authenticate to Wiz" {

  run setupWiz "$WIZ_CLI_CONTAINER" "$WIZ_DIR"

  assert_output --partial "Wiz authentication failed, please confirm the credentials are set for WIZ_CLIENT_ID and WIZ_CLIENT_SECRET"
  assert_failure
}

@test "Missing scan type" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE=""

  run "$PWD/hooks/post-command"
  assert_output "+++ 🚨 Missing scan type. Possible values: 'iac', 'docker', 'dir'"
  assert_failure
}

@test "Docker Scan without BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS" {
  unset BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS

  run "$PWD/hooks/post-command"
  assert_output "+++ 🚨 Missing image address, docker scans require an address to pull the image"

  assert_failure
}

@test "Invalid Scan Format" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT="wrong-format"

  run "$PWD/hooks/post-command"
  assert_output --partial "+++ 🚨 Invalid Scan Format: $BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT"
  
  assert_failure
}

@test "Invalid File Output Format" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT="wrong-format"

  run "$PWD/hooks/post-command"
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT"

  assert_failure
}

@test "Invalid File Output Format (multiple)" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="wrong-format"

  run "$PWD/hooks/post-command"
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"

  assert_failure
}

@test "Duplicate File Output Formats" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="human"

  stub docker : 'exit 0'
  stub docker : 'exit 0'
  stub docker : 'exit 0'
  stub cat : 'exit 0'

  mkdir -p "$WIZ_DIR"
  touch "$WIZ_DIR/key"

  run "$PWD/hooks/post-command"
  assert_output --partial "+++ ⚠️  Duplicate file output format ignored: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"

  assert_success
}

@test "Invalid File Output Format (multiple with duplicates)" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_2="wrong-format"
  
  run "$PWD/hooks/post-command"
  assert_output --partial "+++ ⚠️  Duplicate file output format ignored: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_2"

  assert_failure
}

@test "Get Wiz CLI Container Image (amd64)" {
  stub uname "-m : echo 'x86_64'"

  run get_wiz_cli_container

  assert_success
  assert_output --partial "wiziocli.azurecr.io/wizcli:latest-amd64"

  unstub uname
}

@test "Get Wiz CLI Container Image (arm64)" {
  stub uname "-m : echo 'arm64'"

  run get_wiz_cli_container

  assert_success
  assert_output --partial "wiziocli.azurecr.io/wizcli:latest-arm64"

  unstub uname
}

@test "Get Wiz CLI Container Image (unknown architecture)" {
  stub uname "-m : echo 'unknown'"

  run get_wiz_cli_container

  assert_success
  assert_output --partial "wiziocli.azurecr.io/wizcli:latest"

  unstub uname
}
