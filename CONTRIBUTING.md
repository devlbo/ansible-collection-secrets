# Contributing to devlbo.secrets

Thank you for your interest in contributing to this collection.

## Reporting Bugs

Use the [GitHub issue tracker](https://github.com/devlbo/ansible-collection-secrets/issues)
and select the **Bug Report** template. Include the information requested in the form.

## Requesting Features

Open an issue using the **Feature Request** template.
Describe the use case and proposed solution clearly.

## Submitting Pull Requests

`main` is a protected branch — only the maintainer merges PRs into it.

1. Fork the repository and create a branch from `main` using the naming
   convention `<type>/<short-description>` (e.g. `feat/add-pkcs12-role`,
   `fix/password-hash-encoding`).
   See [DEVELOPMENT.md](DEVELOPMENT.md#branching-model-github-flow)
   for the full branching and commit conventions.
2. Set up your dev environment (see below).
3. Make your changes, following the coding standards below. Use
   [Conventional Commits](DEVELOPMENT.md#commit-conventions-conventional-commits)
   for all commit messages.
4. Run lint and tests before pushing.
5. Open a pull request against `main` with a clear description of the change.

## Dev Setup

Install Python dependencies:

```bash
pip install -r requirements-dev.txt
```

Install Ansible collection dependencies:

```bash
ansible-galaxy collection install -r requirements.yml
```

Install system tools (`sops` 3.8+ and `age` 1.0+):
see [DEVELOPMENT.md](DEVELOPMENT.md#local-prerequisites) for platform-specific instructions.

Install pre-commit hooks:

```bash
pre-commit install
```

## Running Lint

```bash
yamllint -c .yamllint .
ansible-lint
```

## Running Tests

```bash
# Run all Molecule scenarios
./tests/run-role-tests.sh
```

## Coding Standards

This collection follows the standards documented in [`DEVELOPMENT.md`](DEVELOPMENT.md).

Key points:

- Variable, collection and role names must follow the **snake_case** naming convention
- Variable naming convention: `<role>__<name>` (public), `__<role>__<name>` (internal)
- FQCNs required on all module calls
- Every task needs a `name:` starting with an imperative verb
- `changed_when` required on every `command`/`shell` task
- No `ignore_errors: true`
- Security-first defaults. Defaults MUST be the most restrictive reasonable posture
- Idempotent by design. Second run = zero changes. This is a CI gate.
- State-driven convergence. Roles accept `<role>__state: present|absent`. No separate install/remove roles.
