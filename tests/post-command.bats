#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"
load "${BATS_TEST_DIRNAME}/../lib/plugin.bash"
load "${BATS_TEST_DIRNAME}/../lib/shared.bash"

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
  
  assert_failure

  unstub docker
}

@test "Missing scan type" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE=""

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output "+++ 🚨 Missing scan type. Possible values: 'iac', 'docker', 'dir'"
}

@test "Docker Scan without BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS" {
  unset BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS

  run "$PWD/hooks/post-command"
  assert_output "+++ 🚨 Missing image address, docker scans require an address to pull the image"

  assert_failure
}
