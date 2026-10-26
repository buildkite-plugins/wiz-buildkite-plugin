#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"
load "${BATS_TEST_DIRNAME}/../lib/plugin.bash"
load "${BATS_TEST_DIRNAME}/../lib/shared.bash"

# Uncomment the following line to debug stub failures
# export DOCKER_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup() {
  export WIZ_CLIENT_ID="test"
  export WIZ_CLIENT_SECRET="secret"
  export BUILDKITE_JOB_ID="1234-abcd"
  export BUILDKITE_BUILD_ID="1234-abcd"
  export BUILDKITE_LABEL="scan-step"
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

@test "Missing scan type" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE=""

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output "+++ 🚨 Missing scan type. Possible values: 'iac', 'docker', 'dir'"
}

@test "Docker Scan without BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="docker"
  unset BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS

  run "$PWD/hooks/post-command"
  assert_output "+++ 🚨 Missing image address, docker scans require an address to pull the image"

  assert_failure
}

@test "Docker Scan" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="docker"
  export BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS="ubuntu:22.04"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : echo refreshed' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : echo sha256:scanner" \
    'pull "ubuntu:22.04" : exit 0' \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock,readonly sha256:scanner scan container-image ubuntu:22.04 --stdout=human --human-output-file=/scan/result/output : echo "Docker image scanned without policy hits"'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-docker-success' --style 'success' : echo "Annotated Build"'

  run "$PWD/hooks/post-command"

  assert_success
  refute_output --partial "checking the local cache"

  assert_output --partial "Docker image scanned without policy hits"
  assert_output --partial "Annotated Build"

  unstub docker
  unstub buildkite-agent
}

@test "IaC Scan" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="iac"
  export BUILDKITE_PLUGIN_WIZ_PATH="iac/to/scan"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : echo refreshed' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : echo sha256:scanner" \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan sha256:scanner scan dir /scan/iac/to/scan --name 1234-abcd --stdout=human --human-output-file=/scan/result/output : echo "IaC scanned without policy hits"'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-iac-success' --style 'success' : echo "Annotated Build"' \
    'artifact upload check-file : echo "Uploaded check-file"'

  run "$PWD/hooks/post-command"

  assert_success
  refute_output --partial "checking the local cache"

  assert_output --partial "IaC scanned without policy hits"
  assert_output --partial "Annotated Build"
  assert_output --partial "Uploaded check-file"

  unstub docker
  unstub buildkite-agent
}

@test "Directory Scan" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"
  export BUILDKITE_PLUGIN_WIZ_PATH="dir/to/scan"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : echo refreshed' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : echo sha256:scanner" \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan sha256:scanner scan dir /scan/dir/to/scan --name 1234-abcd --stdout=human --human-output-file=/scan/result/output : echo "Directory scanned without policy hits"'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-dir-success' --style 'success' : echo "Annotated Build"' \
    'artifact upload check-file : echo "Uploaded check-file"'

  run "$PWD/hooks/post-command"

  assert_success
  refute_output --partial "checking the local cache"

  assert_output --partial "Directory scanned without policy hits"
  assert_output --partial "Annotated Build"
  assert_output --partial "Uploaded check-file"

  unstub docker
  unstub buildkite-agent
}

@test "Directory Scan defaults path to current directory" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : echo refreshed' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : echo sha256:scanner" \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan sha256:scanner scan dir /scan/. --name 1234-abcd --stdout=human --human-output-file=/scan/result/output : echo "Directory scanned without policy hits"'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-dir-success' --style 'success' : echo "Annotated Build"' \
    'artifact upload check-file : echo "Uploaded check-file"'

  run "$PWD/hooks/post-command"

  assert_success
  refute_output --partial "checking the local cache"

  assert_output --partial "Directory scanned without policy hits"

  unstub docker
  unstub buildkite-agent
}

@test "Directory Scan with disable-sensitive-data-scan" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"
  export BUILDKITE_PLUGIN_WIZ_PATH="dir/to/scan"
  export BUILDKITE_PLUGIN_WIZ_DISABLE_SENSITIVE_DATA_SCAN="true"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : echo refreshed' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : echo sha256:scanner" \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan sha256:scanner scan dir /scan/dir/to/scan --name 1234-abcd --disabled-scanners=SensitiveData --stdout=human --human-output-file=/scan/result/output : echo "Directory scanned without policy hits"'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-dir-success' --style 'success' : echo "Annotated Build"' \
    'artifact upload check-file : echo "Uploaded check-file"'

  run "$PWD/hooks/post-command"

  assert_success
  refute_output --partial "checking the local cache"

  assert_output --partial "Directory scanned without policy hits"

  unstub docker
  unstub buildkite-agent
}

@test "Directory Scan with tags set" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"
  export BUILDKITE_PLUGIN_WIZ_PATH="dir/to/scan"
  export BUILDKITE_PLUGIN_WIZ_TAGS="tag1=test1,tag2=test2,tag3"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : echo refreshed' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : echo sha256:scanner" \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan sha256:scanner scan dir /scan/dir/to/scan --name 1234-abcd --tags=tag1=test1,tag2=test2,tag3 --stdout=human --human-output-file=/scan/result/output : echo "Directory scanned without policy hits"'

  stub buildkite-agent \
    'annotate --append --context 'ctx-wiz-dir-success' --style 'success' : echo "Annotated Build"' \
    'artifact upload check-file : echo "Uploaded check-file"'

  run "$PWD/hooks/post-command"

  assert_success
  refute_output --partial "checking the local cache"

  assert_output --partial "Directory scanned without policy hits"

  unstub docker
  unstub buildkite-agent
}

@test "Directory Scan with Invalid Scan Format" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"
  export BUILDKITE_PLUGIN_WIZ_PATH="dir/to/scan"
  export BUILDKITE_PLUGIN_WIZ_SCAN_FORMAT="invalid"

  run "$PWD/hooks/post-command"

  assert_failure

  assert_output --partial "+++ 🚨 Invalid Scan Format: invalid"
  assert_output --partial "Valid Formats: human json sarif"
}

@test "Directory Scan with Invalid Output Format" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"
  export BUILDKITE_PLUGIN_WIZ_PATH="dir/to/scan"
  export BUILDKITE_PLUGIN_WIZ_FILE_OUTPUT_FORMAT="invalid"

  run "$PWD/hooks/post-command"

  assert_failure

  assert_output --partial "+++ 🚨 Invalid File Output Format: invalid"
  assert_output --partial "Valid Formats: human json sarif csv-zip"
}

@test "Directory Scan with unset Wiz Credentials" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"
  export BUILDKITE_PLUGIN_WIZ_PATH="dir/to/scan"
  unset WIZ_CLIENT_ID
  unset WIZ_CLIENT_SECRET

  run "$PWD/hooks/post-command"

  assert_failure

  assert_output --partial "+++ 🚨 The following required environment variables are not set: WIZ_CLIENT_ID WIZ_CLIENT_SECRET"
}

@test "Docker hook fails when the scanner image cannot be refreshed and is not cached" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="docker"
  export BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS="ubuntu:latest"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : echo "Scanner image refresh failed" >&2; exit 17' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : exit 1"

  run "$PWD/hooks/post-command"

  assert_equal "$status" 1
  assert_output --partial "Scanner image refresh failed"

  unstub docker
}

@test "IaC hook fails when the scanner image cannot be refreshed and is not cached" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="iac"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : echo "Scanner image refresh failed" >&2; exit 17' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : exit 1"

  run "$PWD/hooks/post-command"

  assert_equal "$status" 1
  assert_output --partial "Scanner image refresh failed"

  unstub docker
}

@test "Directory hook fails when the scanner image cannot be refreshed and is not cached" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : echo "Scanner image refresh failed" >&2; exit 17' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : exit 1"

  run "$PWD/hooks/post-command"

  assert_equal "$status" 1
  assert_output --partial "Scanner image refresh failed"

  unstub docker
}

@test "Docker hook uses the cached image ID when refresh fails" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="docker"
  export BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS="ubuntu:latest"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : exit 1' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : echo sha256:cached-scanner" \
    'pull ubuntu:latest : exit 0' \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock,readonly sha256:cached-scanner scan container-image ubuntu:latest --stdout=human --human-output-file=/scan/result/output : echo Scanned'

  stub buildkite-agent \
    'annotate --append --context ctx-wiz-docker-success --style success : echo Annotated'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "checking the local cache"
  assert_output --partial "Scanned"

  unstub docker
  unstub buildkite-agent
}

@test "IaC hook uses the cached image ID when refresh fails" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="iac"
  export BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS="ubuntu:latest"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : exit 1' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : echo sha256:cached-scanner" \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan sha256:cached-scanner scan dir /scan/. --name 1234-abcd --stdout=human --human-output-file=/scan/result/output : echo Scanned'

  stub buildkite-agent \
    'annotate --append --context ctx-wiz-iac-success --style success : echo Annotated' \
    'artifact upload check-file : echo Uploaded'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "checking the local cache"
  assert_output --partial "Scanned"

  unstub docker
  unstub buildkite-agent
}

@test "Directory hook uses the cached image ID when refresh fails" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"
  export BUILDKITE_PLUGIN_WIZ_IMAGE_ADDRESS="ubuntu:latest"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1 : exit 1' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1 : echo sha256:cached-scanner" \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan sha256:cached-scanner scan dir /scan/. --name 1234-abcd --stdout=human --human-output-file=/scan/result/output : echo Scanned'

  stub buildkite-agent \
    'annotate --append --context ctx-wiz-dir-success --style success : echo Annotated' \
    'artifact upload check-file : echo Uploaded'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "checking the local cache"
  assert_output --partial "Scanned"

  unstub docker
  unstub buildkite-agent
}

@test "Directory hook pulls the configured version tag and runs its resolved image ID" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"
  export BUILDKITE_PLUGIN_WIZ_CLI_IMAGE="public-registry.wiz.io/wiz-app/wizcli:1.81.0"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli:1.81.0 : echo Refreshed' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli:1.81.0 : echo sha256:pinned-scanner" \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan sha256:pinned-scanner scan dir /scan/. --name 1234-abcd --stdout=human --human-output-file=/scan/result/output : echo Scanned'

  stub buildkite-agent \
    'annotate --append --context ctx-wiz-dir-success --style success : echo Annotated' \
    'artifact upload check-file : echo Uploaded'

  run "$PWD/hooks/post-command"

  assert_success
  refute_output --partial "checking the local cache"
  assert_output --partial "Scanned"

  unstub docker
  unstub buildkite-agent
}

@test "Directory hook pulls the configured digest and runs its resolved image ID" {
  export BUILDKITE_PLUGIN_WIZ_SCAN_TYPE="dir"
  export BUILDKITE_PLUGIN_WIZ_CLI_IMAGE="public-registry.wiz.io/wiz-app/wizcli@sha256:abc123"

  stub docker \
    'pull public-registry.wiz.io/wiz-app/wizcli@sha256:abc123 : echo Refreshed' \
    "image inspect --format '{{.Id}}' public-registry.wiz.io/wiz-app/wizcli@sha256:abc123 : echo sha256:pinned-scanner" \
    'run --rm -e WIZ_CLIENT_ID -e WIZ_CLIENT_SECRET --mount type=bind,src=/plugin,dst=/scan sha256:pinned-scanner scan dir /scan/. --name 1234-abcd --stdout=human --human-output-file=/scan/result/output : echo Scanned'

  stub buildkite-agent \
    'annotate --append --context ctx-wiz-dir-success --style success : echo Annotated' \
    'artifact upload check-file : echo Uploaded'

  run "$PWD/hooks/post-command"

  assert_success
  refute_output --partial "checking the local cache"
  assert_output --partial "Scanned"

  unstub docker
  unstub buildkite-agent
}
