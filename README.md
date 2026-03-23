# secrets

Sync `.env` files between machines without storing them in git. Encrypts with [age](https://github.com/FiloSottile/age), stores in a private repo.

## Install

```bash
brew install age
# Clone this repo or copy the `secrets` script to your PATH
```

## Usage

```bash
secrets init              # Create ~/.secrets repo + generate age key
secrets push [project]    # Encrypt .env* files and push
secrets pull [project]    # Pull and decrypt .env* files into current dir
secrets list              # Show all projects
secrets rm <project>      # Remove a project's secrets
secrets rekey             # Re-encrypt everything with a new key
```

If `[project]` is omitted, it's derived from the current directory's git remote or name.

## How it works

```
Your project dir          ~/.secrets/ (private git repo)        GitHub (private)
┌──────────────┐         ┌────────────────────┐               ┌──────────┐
│ .env.staging │──age──▶ │ proj/.env.staging   │──git push──▶ │ encrypted│
│ .env.prod    │ encrypt │        .age         │              │  .age    │
└──────────────┘         │ key.txt (gitignored)│              │  files   │
                         └────────────────────┘               └──────────┘
```

1. `secrets init` generates an age key pair at `~/.secrets/key.txt`
2. `secrets push` encrypts `.env` and `.env.*` files, commits to the secrets repo, pushes
3. On your other machine: `secrets pull` fetches and decrypts into the current directory

The key file must be copied to each machine once (AirDrop, scp, USB).

## Safety

- A pre-commit hook in `~/.secrets/` rejects any plaintext `.env` file
- `.gitignore` blocks `key.txt` and plaintext env files from being committed
- Only `.env` and `.env.*` files are matched (not `.envrc`, `.environment-*`, etc.)

## Testing

```bash
brew install bats-core
bats test/secrets.bats    # 20 tests
```
