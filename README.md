# Wiz Buildkite Plugin

![Wiz logo image](https://github.com/buildkite-plugins/wiz-buildkite-plugin/blob/main/wiz-logo.png)

Scans your infrastructure-as-code Cloudformation stacks or docker images for security vulnerabilities using [wiz](https://www.wiz.io/)

This plugin is forked from [blstrco/wiz-buildkite-plugin](https://github.com/blstrco/wiz-buildkite-plugin).

## Requirements

In order to use this plugin, you will need to have the following installed on your buildkite agent:

- Docker

And the following environment variables exported in the job (e.g. via an Agent hook or Plugin):

- WIZ_CLIENT_ID (Wiz service account's client ID)
- WIZ_CLIENT_SECRET (Wiz service account's secret)

Check out [Buildkite's documentation](https://buildkite.com/docs/pipelines/security/secrets/managing) for more information on how to manage secrets in Buildkite.

## Migrating from v2 to v3

v3 upgrades the underlying Wiz CLI from v0.x to v1.x. WizCLI v0.x reached End of Support on April 15, 2026.

Breaking changes:

- The `show-secret-snippets` option has been removed (not supported by WizCLI v1 scan commands).
- Authentication is now handled inline by scan commands via `WIZ_CLIENT_ID` and `WIZ_CLIENT_SECRET` environment variables, rather than a separate auth step.
- Three new `iac-type` values are supported: `Bicep`, `GitHubActions`, and `Pulumi`.
- A new `sensitive-data` option enables sensitive data detection for Docker image scans.

No changes are required to your pipeline YAML unless you were using `show-secret-snippets`.

## Examples

### Docker Scanning

Add the following to your `pipeline.yml`, the plugin will pull the image, scan it using wiz and create a buildkite annotation with the results.

```yml
steps:
  - command: ls
    plugins:
      - wiz#v3.0.0:
          scan-type: 'docker'
          image-address: "<image-address-to-pull-and-scan>"
```

### AWS `cdk diff` Scanning

To avoid adding build time overhead, you can add IaC scanning to your `cdk diff` step. You will need to mount/export the `cdk.out` folder and pass its path to the plugin. The plugin will then scan each Cloudformation stack in the folder and create a buildkite annotation with the results.

```yml
steps:
  - command: ls
    plugins:
      - docker-compose#v5.12.1:
          volumes:
            - './infrastructure/cdk.out:/app/infrastructure/cdk.out'
      - wiz#v3.0.0:
          scan-type: 'iac'
          path: "infrastructure/cdk.out"
```

### CloudFormation templates Scanning

Add the following to your `pipeline.yml`, the plugin will scan a specific CloudFormation template and related Parameter file.

```yaml
steps:
  - label: "Scan CloudFormation template file"
    command: ls
    plugins:
      - wiz#v3.0.0:
          scan-type: 'iac'
          iac-type: 'Cloudformation'
          path: 'cf-template.yaml'
          parameter-files: 'params.json'
```

This can also be used to scan CloudFormation templates that have been synthesized via the AWS CDK e.g., `cdk synth > example.yaml`

### Terraform Files Scanning

Add the following to your `pipeline.yml`, the plugin will scan a specific Terraform File and related Parameter file.

```yaml
steps:
  - label: "Scan Terraform File"
    command: ls *.tf
    plugins:
      - wiz#v3.0.0:
          scan-type: 'iac'
          iac-type: 'Terraform'
          path: 'main.tf'
          parameter-files: 'variables.tf'
```

By default, `path` parameter will be the root of your repository, and scan all Terraform files in the directory.
To change the directory, add the following to your `pipeline.yml`, the plugin will scan the chosen directory.

```yaml
steps:
  - label: "Scan Terraform Files in Directory"
    command: ls my-terraform-dir/*.tf
    plugins:
      - wiz#v3.0.0:
          scan-type: 'iac'
          iac-type: 'Terraform'
          path: 'my-terraform-dir'
```

### Terraform Plan Scanning

Add the following to your `pipeline.yml`, the plugin will scan a Terraform Plan.

```yaml
steps:
  - label: "Scan Terraform Plan"
    command: terraform plan -out plan.tfplan && terraform show -json plan.tfplan | jq -er . > plan.tfplanjson
    plugins:
      - wiz#v3.0.0:
          scan-type: 'iac'
          iac-type: 'Terraform'
          path: 'plan.tfplanjson'
```

### Directory Scanning

Add the following to your `pipeline.yml`, the plugin will scan a directory.

```yaml
steps:
  - label: "Scan Directory"
    command: ls .
    plugins:
      - wiz#v3.0.0:
          scan-type: 'dir'
          path: 'src'
```

By default, `path` parameter will be the root of your repository, and scan all files in the local directory.
To change the directory, add the following to your `pipeline.yml`, the plugin will scan the chosen directory.

```yaml
steps:
  - label: "Scan Files in different Directory"
    command: ls my-dir
    plugins:
      - wiz#v3.0.0:
          scan-type: 'dir'
          path: 'my-dir'
```

## Configuration

### `scan-type` (Required, string): `dir | docker | iac`

The type of resource to be scanned.

### `iac-type` (Optional, string): `Ansible | AzureResourceManager | Bicep | Cloudformation | Dockerfile | GitHubActions | GoogleCloudDeploymentManager | Kubernetes | Pulumi | Terraform`

Narrow down the scan to specific type.
Used when `scan-type` is `iac` or `dir`.

### `image-address` (Optional, string)

The container registry address of the image to scan (e.g., `myregistry.io/image:tag`). Required when `scan-type` is `docker`.

### `scan-format` (Optional, string): `human | json | sarif`

Scans output format.
Defaults to: `human`

### `file-output-format` (Optional, string or array): `human | json | sarif | csv-zip`

Generates an additional output file with the specified format.

### `parameter-files` (Optional, string)

Comma separated list of globs of external parameter files to include while scanning e.g., `variables.tf`
Used when `scan-type` is `iac` or `dir`.

### `path` (Optional, string)

The file or directory to scan.
Used when `scan-type` is `dir` or `iac`.
Defaults to: repository root (`.`)

### `sensitive-data` (Optional, bool)

Enable sensitive data detection (PII, PCI, PHI) for Docker image scans.
Defaults to: `false`

## Developing

To run the tests:

```shell
docker compose run --rm tests
```

## Contributing

1. Fork the repo
2. Make the changes
3. Run the tests
4. Commit and push your changes
5. Send a pull request
