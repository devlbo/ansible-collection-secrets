# devlbo.secrets.ssh_keys

## Purpose

This role generates SSH keypairs with optional passphrase protection and
persists the metadata into per-user SOPS-encrypted YAML files using age keys.
SSH key files and SOPS metadata files are co-located in the same output directory.

## Why this role?

GitOps workflows need secrets to be version-controlled alongside infrastructure
code — but plaintext secrets in git are a security risk.

This role encrypts every ssh passphrase with [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age) before writing it to disk.

It can also include a copy of the SSH private key in the encrypted file to transfer the SSH private key safely to another location. NEVER commit unencrypted SSH private keys to git.

The resulting `.sops.yaml` files are **safe to commit to git**. They can be
consumed by:

- **Ansible** via the [`community.sops`](https://github.com/ansible-collections/community.sops)
  collection (e.g., `community.sops.load_vars`)
- **Terraform / OpenTofu** via the SOPS provider (e.g.,
  [`carlpett/sops`](https://registry.terraform.io/providers/carlpett/sops/latest))

No plaintext secrets ever touch disk or appear in git history.

## Scope — This role owns

- Generating SSH keypairs (ed25519, RSA, ECDSA) with configurable naming.
- Generating random passphrases for SSH key protection with configurable
  complexity constraints (minimum per character class: lower, upper, numeric,
  special).
- Writing per-user SOPS-encrypted YAML files with SSH key metadata (custom or
  default naming).
- Wiping sensitive facts from Ansible memory after encryption.
- Removing SOPS files and SSH key artifacts when state is absent.

## Scope — This role does NOT own

- Generating passwords or password hashes. That is the responsibility of the
  `devlbo.secrets.passwords` role.
- Provisioning user accounts on target systems. That is the responsibility of
  other bootstrap roles or playbooks that are not part of this collection.
- Managing age keys or SOPS configuration. The operator must provide age public
  keys or a `.sops.yaml` file.
- Distributing secrets to target hosts. Downstream playbooks or Terraform/OpenTofu
  consume the SOPS files this role produces.

## Assumptions

- Runs on `localhost` with `connection: local`. No remote hosts needed.
- `sops` and `age` binaries are installed on the control node.
- `community.general`, `community.crypto`, and `community.sops` collections
  are installed.
- Age public keys are provided via variable or `.sops.yaml` file.

## Supported Platforms

This role runs on the Ansible control node (localhost). It requires:

| Dependency        | Minimum version |
| ----------------- | --------------- |
| Ansible           | 2.16+           |
| sops              | 3.8+            |
| age               | 1.0+            |
| community.general | 11.0.0+         |
| community.crypto  | 2.14.0+         |
| community.sops    | 2.0.0+          |
| ansible.posix     | 2.0.0+          |

## Variable Naming Convention

- Public variables: `ssh_keys__<name>` (double underscore separator).
- Internal variables: `__ssh_keys__<name>` (leading double underscore).
- See `meta/argument_specs.yml` for the full typed contract.

## Variables

See `defaults/main.yml` for all public variables with defaults and comments.
See `meta/argument_specs.yml` for the formal typed specification.

### Global controls

| Variable                   | Type | Default   | Description                                 |
| -------------------------- | ---- | --------- | ------------------------------------------- |
| `ssh_keys__state`          | str  | `present` | Global state: `present` or `absent`         |
| `ssh_keys__users`          | list | `[]`      | User definitions (see schema below)         |
| `ssh_keys__passphrase`     | bool | `true`    | Generate key passphrases globally           |
| `ssh_keys__confirm_absent` | bool | `false`   | Safety gate: must be `true` to delete files |

### SSH key configuration

| Variable                    | Type | Default           | Description                                                                     |
| --------------------------- | ---- | ----------------- | ------------------------------------------------------------------------------- |
| `ssh_keys__ssh_key_type`    | str  | `ed25519`         | Key type (`ed25519`, `rsa`, `ecdsa`)                                            |
| `ssh_keys__ssh_key_bits`    | int  | `null`            | Key bits (RSA only)                                                             |
| `ssh_keys__output_dir`      | str  | `~/.secrets/.ssh` | Directory for SSH key files and SOPS metadata (co-located). Must not be empty.  |
| `ssh_keys__ssh_key_in_sops` | bool | `false`           | Additionally embed raw private key content in SOPS file alongside the file path |

### Passphrase policy

| Variable                             | Type | Default                     | Description                      |
| ------------------------------------ | ---- | --------------------------- | -------------------------------- |
| `ssh_keys__passphrase_length`        | int  | `48`                        | Total passphrase length (min 12) |
| `ssh_keys__passphrase_min_lower`     | int  | `6`                         | Minimum lowercase letters        |
| `ssh_keys__passphrase_min_upper`     | int  | `6`                         | Minimum uppercase letters        |
| `ssh_keys__passphrase_min_numeric`   | int  | `6`                         | Minimum numeric characters       |
| `ssh_keys__passphrase_min_special`   | int  | `6`                         | Minimum special characters       |
| `ssh_keys__passphrase_special_chars` | str  | `!@#$%^&*()_+-=[]{};:,.<>?` | Allowed special characters       |

**Validation:** The sum of all `min_*` values must not exceed `passphrase_length`.

### SOPS / age encryption

| Variable                     | Type | Default | Description                                      |
| ---------------------------- | ---- | ------- | ------------------------------------------------ |
| `ssh_keys__age_public_keys`  | list | `[]`    | Age keys (empty = falls back to next precedence) |
| `ssh_keys__sops_config_path` | str  | `""`    | Path to a `.sops.yaml` config file (optional)    |

**Encryption precedence** (highest to lowest):

1. `age_public_keys` (global or per-user) — passed as `age:` to SOPS
2. `sops_config_path` (global or per-user) — passed as `config_path:` to SOPS
3. `SOPS_AGE_RECIPIENTS` environment variable — used as age keys
4. Automatic `.sops.yaml` discovery — SOPS default behavior

Per-user `age_public_keys` and `sops_config_path` override their global
counterparts for that specific user.

### Overwrite behavior

| Variable              | Type | Default | Description                                  |
| --------------------- | ---- | ------- | -------------------------------------------- |
| `ssh_keys__overwrite` | bool | `false` | Overwrite existing SSH keypair and SOPS file |

### User definition schema

```yaml
ssh_keys__users:
  - username: sysadmin                       # Required. Used in default key name and SOPS filename.
    state: present                           # Optional. Default: present.
    passphrase: true                         # Optional. Overrides global flag.
    ssh_key_name: id_ed25519_prod            # Optional. Default: id_<type>_<username>
    ssh_key_comment: admin@corp.com          # Optional. Default: <user>
    sops_filename: id_ed25519_prod.sops.yaml # Optional. Default: <keyname>.sops.yaml
    ssh_key_in_sops: true                    # Optional. Override global ssh_keys__ssh_key_in_sops.
    age_public_keys:                         # Optional. Override global ssh_keys__age_public_keys.
      - "age1..."
    sops_config_path: ".sops.yaml"          # Optional. Override global ssh_keys__sops_config_path.
    confirm_absent: true                     # Optional. Override global ssh_keys__confirm_absent.
    metadata:                                # Optional. Free-form dict. Omitted when empty.
      url: "https://example.com"
      environment: production
```

### SOPS file content

The SOPS file structure depends on `ssh_keys__ssh_key_in_sops`:

**Path mode** (default, `ssh_key_in_sops: false`, with passphrase):

```yaml
# Decrypted structure:
username: sysadmin
ssh_passphrase: "<generated>"          # omitted if passphrase=false
ssh_key_name: id_ed25519_sysadmin
ssh_private_key_path: /path/to/key     # path, NOT content
ssh_public_key: "ssh-ed25519 AA..."
ssh_fingerprint: "SHA256:..."
ssh_comment: "sysadmin"
```

**Path mode without passphrase** (`passphrase: false`):

```yaml
# Decrypted structure (ssh_passphrase omitted):
username: deploy
ssh_key_name: id_ed25519_deploy
ssh_private_key_path: /path/to/key
ssh_public_key: "ssh-ed25519 AA..."
ssh_fingerprint: "SHA256:..."
ssh_comment: "deploy"
```

**Content mode** (`ssh_key_in_sops: true`):

```yaml
# Decrypted structure:
username: sysadmin
ssh_passphrase: "<generated>"
ssh_key_name: id_ed25519_sysadmin
ssh_private_key_path: /path/to/key     # path always present
ssh_private_key: |                     # raw PEM content (additive)
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
ssh_public_key: "ssh-ed25519 AA..."
ssh_fingerprint: "SHA256:..."
ssh_comment: "sysadmin"
```

**With metadata** (any mode, when `metadata` is non-empty):

```yaml
# Decrypted structure:
username: webapp
ssh_passphrase: "<generated>"
ssh_key_name: id_ed25519_webapp
ssh_private_key_path: /path/to/key
ssh_public_key: "ssh-ed25519 AA..."
ssh_fingerprint: "SHA256:..."
ssh_comment: "webapp"
metadata:
  url: "https://webapp.example.com"
  environment: production
```

In path mode (default), `ssh_private_key_path` records the key file location.
In content mode, the raw private key PEM is additionally stored in
`ssh_private_key`, which is useful when keys need to be distributed without
file access to the control node.

## Example Playbook

### Minimal usage

SSH keys and SOPS metadata are written to `~/.secrets/.ssh` by default.
For a user `sysadmin` the output would be:

```text
~/.secrets/.ssh/id_ed25519_sysadmin        # private key
~/.secrets/.ssh/id_ed25519_sysadmin.pub    # public key
~/.secrets/.ssh/id_ed25519_sysadmin.sops.yaml  # encrypted metadata
```

```yaml
- hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: devlbo.secrets.ssh_keys
      vars:
        ssh_keys__users:
          - username: sysadmin
          - username: deploy
            passphrase: false
```

### Full featured with custom naming and less strict policy

```yaml
- hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: devlbo.secrets.ssh_keys
      vars:
        ssh_keys__age_public_keys:
          - "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
        ssh_keys__output_dir: "./infra/ssh_keys"

        # Strict passphrase policy
        ssh_keys__passphrase_length: 32
        ssh_keys__passphrase_min_lower: 4
        ssh_keys__passphrase_min_upper: 4
        ssh_keys__passphrase_min_numeric: 3
        ssh_keys__passphrase_min_special: 2

        ssh_keys__users:
          - username: sysadmin
            passphrase: true
            ssh_key_name: id_ed25519_sysadmin_prod
            ssh_key_comment: sysadmin@mycompany.com

          - username: deploy
            passphrase: false
            age_public_keys:
              - "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"

          - username: webapp
            passphrase: true
            metadata:
              url: "https://webapp.example.com"
              environment: production
              notes: "Primary webapp service account"
```

### Overwrite existing secrets

```bash
ansible-playbook devlbo.secrets.provision_ssh_keys \
  -e ssh_keys__overwrite=true \
  -e @vars/users.yml
```

### Remove secrets (two-step workflow)

First run without `confirm_absent` to preview what would be deleted:

```yaml
- hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: devlbo.secrets.ssh_keys
      vars:
        ssh_keys__state: absent
        ssh_keys__users:
          - username: old_user
          - username: sysadmin
            ssh_key_name: id_ed25519_sysadmin_prod
            sops_filename: id_ed25519_sysadmin_prod.sops.yaml
```

After reviewing the dry-run warning output, re-run with `confirm_absent: true`
to execute the deletion:

```yaml
- hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: devlbo.secrets.ssh_keys
      vars:
        ssh_keys__state: absent
        ssh_keys__confirm_absent: true
        ssh_keys__users:
          - username: old_user
          - username: sysadmin
            ssh_key_name: id_ed25519_sysadmin_prod
            sops_filename: id_ed25519_sysadmin_prod.sops.yaml
```

Use per-user `confirm_absent` to delete specific users while preserving others:

```yaml
        ssh_keys__state: absent
        ssh_keys__users:
          - username: old_user
            confirm_absent: true   # deleted (SOPS + private key + public key)
          - username: keep_user   # preserved (no per-user confirm_absent)
```

## Tags

| Tag        | Scope                 |
| ---------- | --------------------- |
| `ssh_keys` | All tasks in the role |

## Security considerations

- Sensitive data (passphrases, private key content) is wiped from Ansible's
  fact scope immediately after SOPS encryption completes.
- All tasks handling secrets use `no_log: true` to prevent leaking values in
  Ansible output.
- SOPS encryption uses `community.sops.sops_encrypt` with `content_yaml`,
  meaning plaintext data goes from Ansible variable directly to the encrypted
  file without ever touching disk unencrypted.
- In path mode (default), SSH private key content is **not** stored in the
  SOPS file. In content mode (`ssh_key_in_sops: true`), the raw PEM is
  stored inside the SOPS-encrypted file. Evaluate your threat model before
  enabling content mode.
- SSH keys are always generated in per-user temp directories that are
  guaranteed to be cleaned up via `block/always`, even on failure. This
  avoids cross-OS issues (e.g., devcontainer on Windows) with shared temp
  directories.
- Passphrase generation uses `min_*` constraints on the
  `community.general.random_string` lookup to guarantee character class
  diversity, preventing statistically possible all-lowercase or all-numeric
  outputs.
- The output path (`ssh_keys__output_dir`) is normalized internally via
  `| normpath` to prevent path traversal issues.
- Absent state requires explicit `ssh_keys__confirm_absent: true` before any
  files are deleted. The default dry-run mode shows which files would be
  removed without touching them, preventing accidental loss of SSH keypairs.

## Dependencies

None. Composition is the playbook's responsibility.
