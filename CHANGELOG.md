# Changelog

All notable changes to this collection will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this collection adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-20

### Added

- `passwords` role: generate and persist encrypted user passwords and password
  hashes into per-user SOPS files (`<username>.sops.yaml`).
  - Password generation with configurable complexity constraints
    (`min_lower`, `min_upper`, `min_numeric`, `min_special`).
  - SHA512, SHA256, and bcrypt password hashing.
  - Single `passwords__overwrite` flag (one artifact per user).
  - Normalized output paths (`passwords__output_dir`)
    via `| normpath` to resolve trailing slashes and `..` segments.
- `ssh_keys` role: generate SSH keypairs with optional passphrase protection
  and persist metadata into per-user SOPS files (`<keyname>.sops.yaml`).
  - SSH keypair generation (ed25519, RSA, ECDSA) with optional passphrase
    protection and independent complexity policy.
  - Custom naming for SSH keys (`ssh_key_name`), SSH key comments
    (`ssh_key_comment`), and SOPS output files (`sops_filename`).
  - Single `ssh_keys__overwrite` flag (three artifacts per user).
  - `ssh_passphrase` field is omitted from SOPS output
    when no passphrase is generated (`passphrase: false`),
    instead of storing an empty string.
  - `ssh_keys__ssh_key_in_sops` flag: when true, stores raw SSH private key
    PEM content in the SOPS file (`ssh_private_key` field).
  - Normalized output paths (`ssh_keys__output_dir`)
    via `| normpath` to resolve trailing slashes and `..` segments.
  - Per-user temp directories with `block/always` cleanup for SSH key generation,
    replacing the global temp directory to fix cross-OS issues.
- Per-user `metadata` field for both `passwords` and `ssh_keys` roles:
  free-form dict included in SOPS output under a `metadata` key. When
  empty (default), the key is omitted entirely from the SOPS file.
- SOPS encryption via `community.sops.sops_encrypt` — secrets never touch
  disk unencrypted.
- Sensitive facts wiped from Ansible memory after encryption.
- Input validation with clear error messages (tool prerequisites, policy
  constraints, `min_*` sum <= length).
- State management: `present` creates, `absent` removes (global and per-user).
- Molecule test suite for each role covering all code paths.
- `provision_passwords` playbook for standalone password orchestration.
- `provision_ssh_keys` playbook for standalone SSH key orchestration.
- `provision_secrets` playbook for combined orchestration (runs both roles).

[1.0.0]: https://github.com/devlbo/ansible-collection-secrets/releases/tag/1.0.0
