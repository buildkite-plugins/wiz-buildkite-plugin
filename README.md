# Wiz Buildkite Plugin

![Wiz logo image](https://github.com/buildkite-plugins/wiz-buildkite-plugin/blob/main/wiz-logo.png)

Scans your infrastructure-as-code Cloudformation stacks or docker images for security vulnerabilities using [wiz](https://www.wiz.io/)

This plugin is forked from [blstrco/wiz-buildkite-plugin](https://github.com/blstrco/wiz-buildkite-plugin).

## Examples

### Docker Scanning

Add the following to your `pipeline.yml`, the plugin will pull the image, scan it using wiz and create a buildkite annotation with the results.

```yml
steps:
  - command: ls
    env:
    - WIZ_API_ID: "<your-id-goes-here>"
    plugins:
      - wiz#v1.4.0:
          scan-type: 'docker'
          image-address: "<image-address-to-pull-and-scan>"
```

If you are using the [AWS Assume Role Plugin](https://github.com/cultureamp/aws-assume-role-buildkite-plugin), you might have trouble getting your secret key from `aws secretsmanager` if the role you assumed doesn't have the necessary access rights. To restore your role, you can use the [AWS Restore Role Buildkite Plugin](https://github.com/franklin-ross/aws-restore-role-buildkite-plugin) before the wiz plugin.

```yml
  plugins:
      - franklin-ross/aws-restore-role#HEAD
      - wiz#v1.4.0:
        scan-type: 'docker'
```

### AWS `cdk diff` Scanning

To avoid adding build time overhead, you can add IaC scanning to your `cdk diff` step. You will need to mount/export the `cdk.out` folder and pass its path to the plugin. The plugin will then scan each Cloudformation stack in the folder and create a buildkite annotation with the results.

```yml
steps:
  - command: ls
    env:
    - WIZ_API_ID: "<your-id-goes-here>"
    plugins:
      - docker-compose#v4.16.0:
        # to get the output of CDK diff, mount the volume in cdk diff stage
        - volumes:
          - './infrastructure/cdk.out:/app/infrastructure/cdk.out'
      - wiz#v1.4.0:
          scan-type: 'iac'
          path: "infrastructure/cdk.out"
```

### CloudFormation templates Scanning

Add the following to your `pipeline.yml`, the plugin will scan a specific CloudFormation template and related Parameter file.

```yaml
steps:
  - label: "Scan CloudFormation template file"
    command: ls
    env:
    - WIZ_API_ID: "<your-id-goes-here>"
    plugins:
      - wiz#v1.4.0:
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
    env:
    - WIZ_API_ID: "<your-id-goes-here>"
    plugins:
      - wiz#v1.4.0:
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
    env:
    - WIZ_API_ID: "<your-id-goes-here>"
    plugins:
      - wiz#v1.4.0:
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
    env:
    - WIZ_API_ID: "<your-id-goes-here>"
    plugins:
      - wiz#v1.4.0:
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
    env:
    - WIZ_API_ID: "<your-id-goes-here>"
    plugins:
      - wiz#v1.4.0:
          scan-type: 'dir'
          path: 'main.tf'
```

By default, `path` parameter will be the root of your repository, and scan all files in the local directory.
To change the directory, add the following to your `pipeline.yml`, the plugin will scan the chosen directory.

```yaml
steps:
  - label: "Scan Files in different Directory"
    command: ls my-dir
    env:
    - WIZ_API_ID: "<your-id-goes-here>"
    plugins:
      - wiz#v1.4.0:
          scan-type: 'dir'
          path: 'my-dir'
```

## Configuration

### `api-secret-env` (Optional, string)

The environment variable that the Wiz API Secret is stored in. Defaults to using `WIZ_API_SECRET`. Refer to the [documentation](https://buildkite.com/docs/pipelines/secrets#using-a-secrets-storage-service) for more information about managing secrets on your Buildkite agents.

### `scan-type` (Required, string) : `dir | docker | iac'

The type of resource to be scanned.

### `iac-type` (Optional, string): `Ansible | AzureResourceManager | Cloudformation | Dockerfile | GoogleCloudDeploymentManager | Kubernetes | Terraform`

Narrow down the scan to specific type.
Used when `scan-type` is `iac`.

### `image-address` (Optional, string)

The path to image file, if the `scan-type` is `docker`.

### `scan-format` (Optional, string): `human | json | sarif`

Scans output format.
Defaults to: `human`

### `file-output-format` (Optional, string or array): `human | json | sarif | csv-zip`

Generates an additional output file with the specified format.
Defaults to: `human`

### `parameter-files` (Optional, string)

Comma separated list of globs of external parameter files to include while scanning e.g., `variables.tf`
Used when `scan-type` is `iac`.

### `path` (Optional, string)

The file or directory to scan, defaults to the root directory of repository.
Used when `scan-type` is `dir` or `iac`.

### `show-secret-snippets` (Optional, bool)

Enable snippets in secrets.
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
