# Development Guide

## Repository structure

```text
ansible-collection-secrets/          ← GitHub repo name
├── .github/workflows/ci.yml         ← CI: lint → molecule → build → release
├── .gitignore
├── .ansible-lint.yaml
├── .yamllint
├── CHANGELOG.md
├── DEVELOPMENT.md                   ← this file
├── LICENSE                          ← MIT
├── README.md                        ← collection-level (Galaxy landing page)
├── galaxy.yml                       ← collection metadata
├── requirements.yml                 ← collection dependencies
├── playbooks/
│   │── provision_secrets.yml
│   │── provision_passwords.yml
│   └── provision_ssh_keys.yml
└── roles/
    │── passwords/
    └── ssh_keys/
        ├── README.md                ← role-level documentation
        ├── defaults/main.yml
        ├── vars/main.yml
        ├── tasks/
        ├── meta/
        └── molecule/default/
```

## Ansible Coding Standards

### Key Principles

1. Roles do configuration. Playbooks do orchestration. Never mix.
2. One responsibility per role. If describing scope requires "and", split.
3. Roles MUST NOT call other roles (`include_role`/`import_role` inside roles
   is forbidden).
4. Roles MUST NOT reference inventory groups, environment names, or other
   roles' variables.
5. Security-first defaults. Defaults MUST be the most restrictive reasonable
   posture.
6. Idempotent by design. Second run = zero changes. This is a CI gate.
7. State-driven convergence. Roles accept `<role>__state: present|absent`. No
   separate install/remove roles.
8. Flat > clever. Optimize for grep-ability, not DRY elegance.

### Global Guidelines

- Variable, collection and role names must follow the **snake_case** naming convention
- FQCNs required on all module calls
- Every task needs a `name:` starting with an imperative verb
- `changed_when` required on every `command`/`shell` task
- No `ignore_errors: true`

### Ansible Collection Naming Convention

The GitHub repo is `ansible-collection-secrets` (following `ansible-collection-<name>`).
The Galaxy namespace is `devlbo`, the collection name is `secrets`, so the FQCN is `devlbo.secrets`.
All roles of this collection must be named `devlbo.secrets.<role_name>`.

### Ansible Variable Naming Convention

- Public variables: `ssh_keys__<name>` (double underscore separator).
- Internal variables: `__ssh_keys__<name>` (leading double underscore).
- See `meta/argument_specs.yml` for each role the full typed contract.

## Git Branching model (GitHub Flow)

- `main` is the protected branch — it is always deployable and only the
  maintainer merges into it.
- All work happens on feature branches created from `main`.
- PRs target `main`; the maintainer reviews and merges after CI passes.

**Branch naming convention:** `<type>/<short-description>`, where `<type>`
matches one of the conventional commit types listed below. Examples:

```text
feat/add-pkcs12-role
fix/password-hash-encoding
docs/update-readme
test/passwords-absent-scenario
```

## Git Commit conventions (Conventional Commits)

Format: `<type>(<scope>): <description>`

| Type       | When to use                                     |
| ---------- | ----------------------------------------------- |
| `feat`     | New feature or capability                       |
| `fix`      | Bug fix                                         |
| `docs`     | Documentation only                              |
| `test`     | Test additions or corrections                   |
| `refactor` | Code change that is neither a fix nor a feature |
| `ci`       | CI/CD pipeline changes                          |
| `chore`    | Maintenance (deps, tooling, version bumps)      |

**Scope** is optional and typically the role name (`passwords`, `ssh_keys`)
or `collection`. Examples:

```text
feat(ssh_keys): add PKCS#12 export option
fix(passwords): correct bcrypt hash truncation
docs: update installation instructions
test(passwords): add molecule scenario for absent state
```

## Development workflow

### Local prerequisites

```bash
# Python packages (dev: includes runtime + lint + test tools)
pip install -r requirements-dev.txt

# Collection dependencies
ansible-galaxy collection install -r requirements.yml
```

> **Runtime only:** `requirements.txt` contains only `ansible-core`, `passlib`,
> and `bcrypt`.
> **Development:** `requirements-dev.txt` includes everything
> in `requirements.txt` plus `ansible-lint`, `yamllint`, `molecule`,
> and `pre-commit`.

#### age (1.0+)

- **Debian/Ubuntu:** `sudo apt-get install -y age`
- **macOS:** `brew install age`
- **Other:** [github.com/FiloSottile/age#installation](https://github.com/FiloSottile/age#installation)

#### sops (3.8+)

- **macOS:** `brew install sops`
- **Linux:** download binary from [github.com/getsops/sops/releases](https://github.com/getsops/sops/releases)
- **Other:** [github.com/getsops/sops#install](https://github.com/getsops/sops#install)

### Run linters locally

```bash
yamllint -c .yamllint .
ansible-lint
```

### Run Molecule tests locally

```bash
# Tests pass (all roles)
./tests/run-role-tests.sh

# Or test each role
cd roles/passwords && molecule test -s default && cd ../..
cd roles/ssh_keys && molecule test -s default && cd ../..
```

### Build the collection locally

```bash
ansible-galaxy collection build --force
# Creates: devlbo-secrets-1.0.0.tar.gz
```

### Install locally for testing

```bash
ansible-galaxy collection install devlbo-secrets-1.0.0.tar.gz --force
```

## CI pipeline

CI runs on GitHub Actions (`.github/workflows/ci.yml`).
Galaxy does not provide CI — it only hosts and distributes artifacts.

### Pipeline stages

| Stage       | Trigger                     | What it does                                        |
| ----------- | --------------------------- | --------------------------------------------------- |
| **Lint**    | push, PR                    | yamllint + ansible-lint                             |
| **Test**    | push, PR (after lint)       | Full Molecule test suite per role                   |
| **Build**   | push, PR (after molecule)   | `ansible-galaxy collection build`, uploads artifact |
| **Release** | tag push only (after build) | Publishes to Galaxy + creates GitHub Release        |

### Trigger matrix

| Event              | lint | test | build | release |
| ------------------ | ---- | ---- | ----- | ------- |
| Push to `main`     | Yes  | Yes  | Yes   | No      |
| Pull request       | Yes  | Yes  | Yes   | No      |
| Tag push (`*.*.*`) | Yes  | Yes  | Yes   | Yes     |

## Release process

> **Note:** Releases are performed exclusively by the maintainer.

Releases follow semantic versioning. The version is the **single source of
truth** in `galaxy.yml`. Tags must match exactly.

### Step-by-step release

```bash
# 1. Update the version in galaxy.yml
#    Edit: version: "1.1.0"

# 2. Update CHANGELOG.md with the new version and changes
#    Add a new section under [Unreleased] or create a new version heading

# 3. Commit the version bump
git add galaxy.yml CHANGELOG.md
git commit -m "release: 1.1.0"

# 4. Tag the commit (tag must match galaxy.yml version)
git tag 1.1.0

# 5. Push both the commit and the tag
git push origin main --tags
```

This triggers the CI pipeline. After lint + molecule + build pass, the
**release** job:

1. Builds the collection tarball.
2. Publishes it to Ansible Galaxy using `GALAXY_API_KEY`.
3. Creates a GitHub Release with the tarball attached and auto-generated
   release notes.

### Version numbering guidelines

| Change type                        | Version bump   | Example       |
| ---------------------------------- | -------------- | ------------- |
| New role, breaking variable rename | Major: `X.0.0` | 1.0.0 → 2.0.0 |
| New feature, new optional variable | Minor: `x.Y.0` | 1.0.0 → 1.1.0 |
| Bug fix, docs improvement          | Patch: `x.y.Z` | 1.0.0 → 1.0.1 |

### Pre-release verification

Before tagging, verify locally:

```bash
# Lint passes
yamllint -c .yamllint .
ansible-lint

# Tests pass (all roles)
./tests/run-role-tests.sh

# Or test each role
cd roles/passwords && molecule test -s default && cd ../..
cd roles/ssh_keys && molecule test -s default && cd ../..

# Build succeeds
ansible-galaxy collection build --force

# Version in galaxy.yml matches intended release
grep '^version:' galaxy.yml
```

### Fixing a failed release

If the Galaxy publish fails after tagging:

```bash
# Delete the remote tag
git push origin --delete 1.1.0

# Delete the local tag
git tag -d 1.1.0

# Fix the issue, commit, re-tag, push
git tag 1.1.0
git push origin main --tags
```

## FAQ

**Q: Why GitHub Actions and not Galaxy CI?**
Galaxy is a distribution platform, not a CI system. It performs basic
import validation (schema checks on `galaxy.yml`, MANIFEST.json) but does
not run linters, Molecule tests, or integration tests. All testing must
happen before publishing.

**Q: Can I publish manually without tagging?**
Yes, for debugging:

```bash
ansible-galaxy collection build --force
ansible-galaxy collection publish devlbo-secrets-*.tar.gz --api-key <token>
```

But the tag-based workflow is strongly preferred because it ties Galaxy
versions 1:1 with Git history.

**Q: What if Galaxy rejects the namespace?**
Galaxy namespaces must match your Galaxy username. If `devlbo` is your
GitHub username and you signed into Galaxy with GitHub OAuth, the namespace
`devlbo` is automatically available. Namespaces cannot contain hyphens.

**Q: How do consumers pin a version?**

```yaml
# requirements.yml
collections:
  - name: devlbo.secrets
    version: ">=1.0.0,<2.0.0"
```
