#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"
load "${BATS_TEST_DIRNAME}/../lib/plugin.bash"
load "${BATS_TEST_DIRNAME}/../lib/shared.bash"

setup() {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="docker"
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

@test "Validates Wiz Client Credentials" {
  run validateWizClientCredentials

  assert_success
}

@test "Invalid Wiz Client Credential (ID)" {
  export WIZ_CLIENT_ID=""

  run validateWizClientCredentials

  assert_failure
  assert_output "+++ 🚨 The following required environment variables are not set: WIZ_CLIENT_ID"
}

@test "Invalid Wiz Client Credentials (ID and Secret)" {
  export WIZ_CLIENT_ID=""
  export WIZ_CLIENT_SECRET=""

  run validateWizClientCredentials

  assert_failure
  assert_output "+++ 🚨 The following required environment variables are not set: WIZ_CLIENT_ID WIZ_CLIENT_SECRET"
}

@test "Successfully authenticate to Wiz" {
  mkdir -p "$WIZ_DIR"
  touch "$WIZ_DIR/key"

  stub docker \
    'run --rm -it --mount type=bind,src="$WIZ_DIR",dst=/cli,readonly -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET "wiziocli.azurecr.io/wizcli:latest" auth: exit 0'

  run setupWiz "$WIZ_CLI_CONTAINER" "$WIZ_DIR"

  assert_success

  unstub docker
}

@test "Fail to authenticate to Wiz" {
  stub docker \
    'run --rm -it --mount type=bind,src="$WIZ_DIR",dst=/cli,readonly -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET "wiziocli.azurecr.io/wizcli:latest" auth: exit 0'

  run setupWiz "$WIZ_CLI_CONTAINER" "$WIZ_DIR"

  assert_failure
  assert_output --partial "Wiz authentication failed, please confirm the credentials are set for WIZ_CLIENT_ID and WIZ_CLIENT_SECRET"

  unstub docker
}

@test "Invalid Scan Format" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT="wrong-format"

  run get_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"
  
  assert_failure
  assert_output --partial "+++ 🚨 Invalid Scan Format: $BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT"
}

@test "Invalid File Output Format" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT="wrong-format"

  run get_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"
  
  assert_failure
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT"
}

@test "Invalid File Output Format (multiple)" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="wrong-format"

  run get_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_failure
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"
}

@test "Duplicate File Output Formats" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="human"

  run get_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_success
  assert_output --partial "+++ ⚠️  Duplicate file output format ignored: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"
}

@test "Invalid File Output Format (multiple with duplicates)" {
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_2="wrong-format"
  
  run get_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_failure
  assert_output --partial "+++ ⚠️  Duplicate file output format ignored: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_2"
}

@test "Valid Wiz CLI Args (default)" {
  run get_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_success
  assert_output --partial "--format=human --output=/scan/result/output,human"
}

@test "Valid Wiz CLI Args (custom)" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT="json"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="json"

  run get_wiz_cli_args "$BUILDKITE_PLUGIN_WIZ_SCAN_TYPE"

  assert_success
  assert_output --partial "--format=json --output=/scan/result/output,human --output=/scan/result/output-human,human --output=/scan/result/output-json,json"
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
