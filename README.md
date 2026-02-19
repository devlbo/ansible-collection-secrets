# Ansible Collection: devlbo.secrets

[![CI](https://github.com/devlbo/ansible-collection-secrets/actions/workflows/ci.yml/badge.svg)](https://github.com/devlbo/ansible-collection-secrets/actions/workflows/ci.yml)
[![Galaxy](https://img.shields.io/badge/galaxy-devlbo.secrets-blue.svg)](https://galaxy.ansible.com/ui/repo/published/devlbo/secrets/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Generate and persist encrypted user authentication secrets (passwords, SSH
keypairs, passphrases) into SOPS-encrypted YAML files using age keys.

## Why this collection?

GitOps workflows need secrets to be version-controlled alongside infrastructure
code — but plaintext secrets in git are a security risk.

This collection contributes to safely generate, persist and consume secrets by encrypting every secret with [SOPS](https://github.com/getsops/sops)
and [age](https://github.com/FiloSottile/age) before writing it to disk.

The resulting `.sops.yaml` files are **safe to commit to git**. They can be
consumed by:

- **Ansible** via the [`community.sops`](https://github.com/ansible-collections/community.sops)
  collection (e.g., `community.sops.load_vars`)
- **Terraform / OpenTofu** via the SOPS provider (e.g.,
  [`carlpett/sops`](https://registry.terraform.io/providers/carlpett/sops/latest))

No plaintext secrets ever touch disk or appear in git history.

## Included content

### Roles

- **[devlbo.secrets.passwords](https://github.com/devlbo/ansible-collection-secrets/blob/main/roles/passwords/README.md)** — generate per-user passwords and password hashes; encrypt into SOPS files
- **[devlbo.secrets.ssh_keys](https://github.com/devlbo/ansible-collection-secrets/blob/main/roles/ssh_keys/README.md)** — generate per-user SSH keypairs with optional passphrase; encrypt metadata into SOPS files

### Playbooks

- **`devlbo.secrets.provision_passwords`** — orchestrate passwords role on localhost
- **`devlbo.secrets.provision_ssh_keys`** — orchestrate ssh_keys role on localhost
- **`devlbo.secrets.provision_secrets`** — orchestrate both roles on localhost

## Requirements

### Runtime

- Ansible 2.16+
- [sops](https://github.com/getsops/sops) 3.8+
- [age](https://github.com/FiloSottile/age) 1.0+
- Python: `passlib` ≥ 1.7.4, `bcrypt` ≥ 4.0.0

Install runtime Python packages:

```bash
pip install -r requirements.txt
```

### Ansible collections

- `community.general` ≥ 11.0.0
- `community.crypto` ≥ 2.14.0
- `community.sops` ≥ 2.0.0
- `ansible.posix` ≥ 2.0.0

For `sops` and `age` installation instructions, see [DEVELOPMENT.md](https://github.com/devlbo/ansible-collection-secrets/blob/main/DEVELOPMENT.md#local-prerequisites).

## Installation

### From Ansible Galaxy

```bash
ansible-galaxy collection install devlbo.secrets
```

### From GitHub

```bash
ansible-galaxy collection install git+https://github.com/devlbo/ansible-collection-secrets.git
```

### Pin a specific version

```bash
ansible-galaxy collection install devlbo.secrets:==1.0.0
```

### In a requirements.yml

```yaml
collections:
  - name: devlbo.secrets
    version: ">=1.0.0"
```

## Quick start

### Passwords only

```yaml
- name: Provision passwords
  hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: devlbo.secrets.passwords
      vars:
        passwords__age_public_keys:
          - "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
        passwords__users:
          - username: root
          - username: sysadmin
```

### SSH keys only

With custom SSH key name and comment, and passphrase disabled for deploy user.

```yaml
- name: Provision SSH keys
  hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: devlbo.secrets.ssh_keys
      vars:
        ssh_keys__age_public_keys:
          - "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
        ssh_keys__users:
          - username: sysadmin
            ssh_key_name: id_ed25519_sysadmin_prod
            ssh_key_comment: sysadmin@mycompany.com
          - username: deploy
            passphrase: false
```

### Both roles together

```yaml
- name: Provision user secrets
  hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: devlbo.secrets.passwords
      vars:
        passwords__age_public_keys:
          - "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
        passwords__users:
          - username: root
          - username: sysadmin
    - role: devlbo.secrets.ssh_keys
      vars:
        ssh_keys__age_public_keys:
          - "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
        ssh_keys__users:
          - username: sysadmin
```

Each role produces separate SOPS files per user:

- Passwords: `<username>.sops.yaml`
- SSH keys: `<keyname>.sops.yaml` (e.g., `id_ed25519_sysadmin.sops.yaml`)

See the [passwords role README](https://github.com/devlbo/ansible-collection-secrets/blob/main/roles/passwords/README.md) and the
[ssh_keys role README](https://github.com/devlbo/ansible-collection-secrets/blob/main/roles/ssh_keys/README.md) for complete variable
references, SOPS file schemas, and detailed examples.

## Roadmap

Planned roles for future releases:

- **`sops` role** — automate SOPS binary installation across platforms
- **`age` role** — automate age binary installation across platforms
- **`age_keys` role** — manage age key generation and distribution

## Contributing

See [CONTRIBUTING.md](https://github.com/devlbo/ansible-collection-secrets/blob/main/CONTRIBUTING.md).

## Support

Found this useful? You can support my work with a coffee ☕. It’s greatly appreciated!

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-devlbo-FFDD00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/devlbo)

## License

MIT — see [LICENSE](https://github.com/devlbo/ansible-collection-secrets/blob/main/LICENSE).

## Acknowledgments

- [Ansible](https://github.com/ansible/ansible) by Red Hat — the automation platform this collection is built on.
- [SOPS](https://github.com/getsops/sops) by Mozilla / getsops maintainers — the secrets encryption tool at the heart of this collection.
- [age](https://github.com/FiloSottile/age) by Filippo Valsorda — the modern encryption format recommended for use with SOPS.
