# State and Environment Strategy

## State expectations

This repository does not configure a real Terraform remote backend. It is an offline architecture reference, and no live Azure state is created by the documented workflow.

Consumers adopting this design in a real environment should configure a remote backend outside this repository. Azure Storage with an appropriate container and state key is one possible pattern.

## Environment isolation

Recommended environments:

- development
- test
- production

Each environment should use:

- a distinct state key
- a separate state lock/scope
- separate resource groups and subscriptions where appropriate
- separate variable files
- separate credentials and approval boundaries
- an immutable change and plan review process

## State locking

Remote state storage should enable locking and reject concurrent modifications. State should be encrypted at rest and access should be restricted to the deployment identity.

## Secrets

Real TLS certificates, passwords and credentials must be supplied through an approved secret store or CI secret mechanism. They must not be committed to Terraform files or repository examples.

## CI identity assumptions

Any future deployment workflow should use a workload identity or narrowly scoped service principal. The CI identity should have only the permissions required for the planned Terraform operations. This repository's current CI validates only and must not receive ARM credentials or Azure deployment permissions.

## Backend supply

Consumers can supply backend configuration through:

- environment variables
- a separate backend configuration file
- a deployment pipeline
- approved organization tooling

No storage account, subscription or tenant is hard-coded in this repository.
