# Runbook

## Prerequisites

- Terraform 1.7 or newer.
- No Azure credentials are required for mock-provider validation.

## Local validation

```bash
terraform fmt -check -recursive

for d in \
  terraform/modules/network \
  terraform/modules/ingress \
  terraform/examples/dev
do
  terraform -chdir="$d" init -backend=false -input=false
  terraform -chdir="$d" validate
done

for d in \
  terraform/modules/network \
  terraform/modules/ingress
do
  env HOME="$(mktemp -d)" AZURE_CONFIG_DIR="$(mktemp -d)" terraform -chdir="$d" test
done
```

## Configuration review

Before a real plan:

- Review CIDR values and subnet assignments.
- Review NSG allow rules and deny baselines.
- Confirm App Gateway, WAF and backend host settings.
- Confirm route-table next hops.
- Confirm reserved subnet names.
- Review variable overrides and environment scope.

## Live state considerations

The repository does not configure a live backend or deployment workflow. A future deployment must supply controlled backend configuration and execute only through an approved pipeline.

## Troubleshooting

- Formatting failure: run `terraform fmt -recursive` and review the diff.
- Init failure: inspect provider lock/download configuration.
- Validation failure: correct invalid module arguments or provider constraints.
- Test failure: inspect the failing run/assertion in the `.tftest.hcl` file.
- Unexpected Azure credentials in CI: stop and remove them; these tests require isolated mock-provider configuration.

## Rollback principles

A real deployment should rely on the reviewed Terraform plan, state backup/locking strategy and approved rollback procedure. This repository does not implement live rollback automation.
