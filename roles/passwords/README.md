# devlbo.secrets.passwords

## Purpose

This role generates and persists encrypted user passwords and password hashes
into per-user SOPS-encrypted YAML files using age keys.

## Why this role?

GitOps workflows need secrets to be version-controlled alongside infrastructure
code — but plaintext secrets in git are a security risk.

This role encrypts every user password with [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age) before writing it to disk.

The resulting `.sops.yaml` files are **safe to commit to git**. They can be
consumed by:

- **Ansible** via the [`community.sops`](https://github.com/ansible-collections/community.sops)
  collection (e.g., `community.sops.load_vars`)
- **Terraform / OpenTofu** via the SOPS provider (e.g.,
  [`carlpett/sops`](https://registry.terraform.io/providers/carlpett/sops/latest))

No plaintext secrets ever touch disk or appear in git history.

## Scope — This role owns

- Generating random passwords with configurable complexity constraints
  (minimum per character class: lower, upper, numeric, special).
- Generating SHA512/SHA256/bcrypt password hashes.
- Writing per-user SOPS-encrypted YAML files (custom or default naming).
- Wiping sensitive facts from Ansible memory after encryption.
- Removing SOPS password files when state is absent.

## Scope — This role does NOT own

- Generating SSH keypairs or passphrases. That is the responsibility of the
  `devlbo.secrets.ssh_keys` role.
- Provisioning user accounts on target systems. That is the responsibility of
  other bootstrap roles or playbooks that are not part of this collection.
- Managing age keys or SOPS configuration. The operator must provide age public
  keys or a `.sops.yaml` file.
- Distributing secrets to target hosts. Downstream playbooks or Terraform/OpenTofu
  consume the SOPS files this role produces.

## Assumptions

- Runs on `localhost` with `connection: local`. No remote hosts needed.
- `sops` and `age` binaries are installed on the control node.
- `community.general` and `community.sops` collections are installed.
- Age public keys are provided via variable or `.sops.yaml` file.

## Supported Platforms

This role runs on the Ansible control node (localhost). It requires:

| Dependency        | Minimum version |
| ----------------- | --------------- |
| Ansible           | 2.16+           |
| sops              | 3.8+            |
| age               | 1.0+            |
| community.general | 11.0.0+         |
| community.sops    | 2.0.0+          |
| ansible.posix     | 2.0.0+          |
| passlib (Python)  | 1.7.4+          |
| bcrypt (Python)   | 4.0.0+          |

## Variable Naming Convention

- Public variables: `passwords__<name>` (double underscore separator).
- Internal variables: `__passwords__<name>` (leading double underscore).
- See `meta/argument_specs.yml` for the full typed contract.

## Variables

See `defaults/main.yml` for all public variables with defaults and comments.
See `meta/argument_specs.yml` for the formal typed specification.

### Global controls

| Variable                    | Type | Default   | Description                                 |
| --------------------------- | ---- | --------- | ------------------------------------------- |
| `passwords__state`          | str  | `present` | Global state: `present` or `absent`         |
| `passwords__users`          | list | `[]`      | User definitions (see schema below)         |
| `passwords__confirm_absent` | bool | `false`   | Safety gate: must be `true` to delete files |

### Password policy

| Variable                             | Type | Default                     | Description                                   |
| ------------------------------------ | ---- | --------------------------- | --------------------------------------------- |
| `passwords__password_length`         | int  | `64`                        | Total password length (min 16)                |
| `passwords__password_min_lower`      | int  | `8`                         | Minimum lowercase letters                     |
| `passwords__password_min_upper`      | int  | `8`                         | Minimum uppercase letters                     |
| `passwords__password_min_numeric`    | int  | `8`                         | Minimum numeric characters                    |
| `passwords__password_min_special`    | int  | `8`                         | Minimum special characters                    |
| `passwords__password_special_chars`  | str  | `!@#$%^&*()_+-=[]{};:,.<>?` | Allowed special characters                    |
| `passwords__password_hash_algorithm` | str  | `sha512`                    | Hash algorithm (`sha512`, `sha256`, `bcrypt`) |

**Validation:** The sum of all `min_*` values must not exceed `password_length`.

### SOPS / age encryption

| Variable                      | Type | Default      | Description                                      |
| ----------------------------- | ---- | ------------ | ------------------------------------------------ |
| `passwords__output_dir`       | str  | `~/.secrets` | SOPS output directory                            |
| `passwords__age_public_keys`  | list | `[]`         | Age keys (empty = falls back to next precedence) |
| `passwords__sops_config_path` | str  | `""`         | Path to a `.sops.yaml` config file (optional)    |

**Encryption precedence** (highest to lowest):

1. `age_public_keys` (global or per-user) — passed as `age:` to SOPS
2. `sops_config_path` (global or per-user) — passed as `config_path:` to SOPS
3. `SOPS_AGE_RECIPIENTS` environment variable — used as age keys
4. Automatic `.sops.yaml` discovery — SOPS default behavior

Per-user `age_public_keys` and `sops_config_path` override their global
counterparts for that specific user.

### Overwrite behavior

| Variable               | Type | Default | Description                   |
| ---------------------- | ---- | ------- | ----------------------------- |
| `passwords__overwrite` | bool | `false` | Overwrite existing SOPS files |

### User definition schema

```yaml
passwords__users:
  - username: sysadmin                # Required. Used in default filenames.
    state: present                    # Optional. Default: present.
    sops_filename: admin.sops.yaml    # Optional. Default: <username>.sops.yaml
    age_public_keys:                  # Optional. Override global passwords__age_public_keys.
      - "age1..."
    sops_config_path: ".sops.yaml"   # Optional. Override global passwords__sops_config_path.
    confirm_absent: true              # Optional. Override global passwords__confirm_absent.
    metadata:                         # Optional. Free-form dict. Omitted when empty.
      url: "https://example.com"
      environment: production
```

### SOPS file content

Each generated SOPS file contains:

```yaml
# Decrypted structure (no metadata):
username: sysadmin
password: "<generated>"
password_hash: "$6$..."
```

When `metadata` is provided (non-empty):

```yaml
# Decrypted structure (with metadata):
username: webapp
password: "<generated>"
password_hash: "$6$..."
metadata:
  url: "https://webapp.example.com"
  environment: production
```

## Example Playbook

### Minimal usage

```yaml
- hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: devlbo.secrets.passwords
      vars:
        passwords__users:
          - username: root
          - username: sysadmin
```

### Full featured with less strict policy

```yaml
- hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: devlbo.secrets.passwords
      vars:
        passwords__age_public_keys:
          - "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
        passwords__output_dir: "./infra/secrets"

        # Strict password policy
        passwords__password_length: 48
        passwords__password_min_lower: 5
        passwords__password_min_upper: 5
        passwords__password_min_numeric: 5
        passwords__password_min_special: 5

        passwords__users:
          - username: root
            sops_filename: root_prod.sops.yaml
          - username: sysadmin
          - username: deploy
            age_public_keys:
              - "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
          - username: webapp
            metadata:
              url: "https://webapp.example.com"
              environment: production
              notes: "Primary webapp service account"
```

### Overwrite existing secrets

```bash
ansible-playbook devlbo.secrets.provision_passwords \
  -e passwords__overwrite=true \
  -e @vars/users.yml
```

### Remove secrets (two-step workflow)

First run without `confirm_absent` to preview what would be deleted:

```yaml
- hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: devlbo.secrets.passwords
      vars:
        passwords__state: absent
        passwords__users:
          - username: old_user
          - username: sysadmin
            sops_filename: admin.sops.yaml
```

After reviewing the dry-run warning output, re-run with `confirm_absent: true`
to execute the deletion:

```yaml
- hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: devlbo.secrets.passwords
      vars:
        passwords__state: absent
        passwords__confirm_absent: true
        passwords__users:
          - username: old_user
          - username: sysadmin
            sops_filename: admin.sops.yaml
```

Use per-user `confirm_absent` to delete specific users while preserving others:

```yaml
        passwords__state: absent
        passwords__users:
          - username: old_user
            confirm_absent: true   # deleted
          - username: keep_user   # preserved (no per-user confirm_absent)
```

## Tags

| Tag         | Scope                 |
| ----------- | --------------------- |
| `passwords` | All tasks in the role |

## Security considerations

- Sensitive data (passwords, hashes) is wiped from Ansible's fact scope
  immediately after SOPS encryption completes.
- All tasks handling secrets use `no_log: true` to prevent leaking values in
  Ansible output.
- SOPS encryption uses `community.sops.sops_encrypt` with `content_yaml`,
  meaning plaintext data goes from Ansible variable directly to the encrypted
  file without ever touching disk unencrypted.
- Password generation uses `min_*` constraints on the
  `community.general.random_string` lookup to guarantee character class
  diversity, preventing statistically possible all-lowercase or all-numeric
  outputs.
- Absent state requires explicit `passwords__confirm_absent: true` before any
  files are deleted. The default dry-run mode shows which files would be
  removed without touching them, preventing accidental secret loss.

## Dependencies

None. Composition is the playbook's responsibility.
