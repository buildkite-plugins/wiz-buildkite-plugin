#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup() {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="docker"
  export BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS="ubuntu:22.04"
  export WIZ_DIR="$HOME/.wiz"
}

@test "Captures docker exit code and exits plugin when non-0 status" {

  export WIZ_API_ID="test"
  export WIZ_API_SECRET="secret"

  stub docker : 'exit 1'
  mkdir -p "$WIZ_DIR"
  touch "$WIZ_DIR/key"

  run "$PWD/hooks/post-command"
  #todo test docker scan
  assert_failure
  #cleanup
  rm "$WIZ_DIR/key"
}

@test "Authenticates to wiz using \$WIZ_API_SECRET" {
  export WIZ_API_ID="test"
  export WIZ_API_SECRET="secret"

  stub docker : 'exit 0'
  stub docker : 'exit 0'
  stub docker : 'exit 0'
  mkdir -p "$WIZ_DIR"
  touch "$WIZ_DIR/key"

  run "$PWD/hooks/post-command"

  assert_output --partial "Authenticated successfully"
  #todo test docker scan
  assert_success
  #cleanup
  rm "$WIZ_DIR/key"
}

@test "Authenticates to wiz using \$BUILDKITE_PLUGIN_WIZ_API_SECRET_ENV" {
  export WIZ_API_ID="test"
  export BUILDKITE_PLUGIN_WIZ_API_SECRET_ENV="CUSTOM_WIZ_API_SECRET_ENV"
  export CUSTOM_WIZ_API_SECRET_ENV="secret"

  stub docker : 'exit 0'
  mkdir -p "$WIZ_DIR"
  touch "$WIZ_DIR/key"

  run "$PWD/hooks/post-command"

  assert_output --partial "Authenticated successfully"
  #todo test docker scan
  assert_success
  #cleanup
  rm "$WIZ_DIR/key"
}

@test "No Wiz API Secret password found in \$WIZ_API_SECRET" {
  export WIZ_API_ID="test"
  unset WIZ_API_SECRET

  run "$PWD/hooks/post-command"

  assert_output "+++ 🚨 No Wiz API Secret password found in \$WIZ_API_SECRET"
  assert_failure
}

@test "No Wiz API Secret password found in \$CUSTOM_WIZ_API_SECRET_ENV" {
  export WIZ_API_ID="test"
  export BUILDKITE_PLUGIN_WIZ_API_SECRET_ENV="CUSTOM_WIZ_API_SECRET_ENV"
  export CUSTOM_WIZ_API_SECRET_ENV=""

  run "$PWD/hooks/post-command"

  assert_output "+++ 🚨 No Wiz API Secret password found in \$CUSTOM_WIZ_API_SECRET_ENV"
  assert_failure
}

@test "Missing scan type" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE=""

  run "$PWD/hooks/post-command"
  assert_output "+++ 🚨 Missing scan type. Possible values: 'iac', 'docker', 'dir'"
  assert_failure
}

@test "Docker Scan without BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS" {
  export WIZ_API_ID="test"
  export WIZ_API_SECRET="secret"
  unset BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS

  run "$PWD/hooks/post-command"
  assert_output "+++ 🚨 Missing image address, docker scans require an address to pull the image"

  assert_failure
}

@test "Invalid Scan Format" {
  export WIZ_API_SECRET="secret"
  export BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT="wrong-format"

  run "$PWD/hooks/post-command"
  assert_output --partial "+++ 🚨 Invalid Scan Format: $BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT"
  
  assert_failure
}

@test "Invalid File Output Format" {
  export WIZ_API_SECRET="secret"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT="wrong-format"

  run "$PWD/hooks/post-command"
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT"

  assert_failure
}

@test "Invalid File Output Format (multiple)" {
  export WIZ_API_SECRET="secret"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="wrong-format"

  run "$PWD/hooks/post-command"
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"

  assert_failure
}

@test "Duplicate File Output Formats" {
  export WIZ_API_SECRET="secret"
  export WIZ_API_ID="test"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="human"

  stub docker : 'exit 0'
  mkdir -p "$WIZ_DIR"
  touch "$WIZ_DIR/key"

  run "$PWD/hooks/post-command"
  assert_output --partial "+++ ⚠️  Duplicate file output format ignored: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"

  assert_success
}

@test "Invalid File Output Format (multiple with duplicates)" {
  export WIZ_API_SECRET="secret"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_0="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1="human"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_2="wrong-format"
  
  run "$PWD/hooks/post-command"
  assert_output --partial "+++ ⚠️  Duplicate file output format ignored: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_1"
  assert_output --partial "+++ 🚨 Invalid File Output Format: $BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT_2"

  assert_failure
}