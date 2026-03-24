# secrets

Sync `.env` files between machines without storing them in git. Encrypts with [age](https://github.com/FiloSottile/age), stores in a private repo.

## Install

```bash
# 1. Install age (encryption tool)
brew install age

# 2. Clone this repo (the tool's source code)
git clone git@github.com:<you>/secrets.git ~/dev/secrets

# 3. Add it to your PATH (e.g., in ~/.zshrc)
export PATH="$HOME/dev/secrets:$PATH"

# 4. Initialize the encrypted secrets store (separate repo)
secrets init

# 5. Create a PRIVATE repo on GitHub for your encrypted secrets, then:
cd ~/.secrets
git remote add origin git@github.com:<you>/my-secrets.git
git push -u origin main

# 6. Copy the key file to your other machine (one-time)
scp ~/.secrets/key.txt <other-machine>:~/.secrets/key.txt
```

This repo (`~/dev/secrets`) is the **tool** — the CLI script, tests, and docs.
`~/.secrets/` is the **encrypted secrets store** — a separate private git repo
where your `.env.age` files live. They are two different repos.

## Usage

```bash
secrets init                  # Create ~/.secrets repo + generate age key
secrets push [project]        # Encrypt .env* files and push
secrets pull [project]        # Pull and decrypt .env* files into current dir
secrets push -w|--workspaces  # Push .env* from all package.json workspaces
secrets pull -w|--workspaces  # Pull .env* into all package.json workspaces
secrets list                  # Show all projects
secrets rm <project>          # Remove a project's secrets
secrets rekey                 # Re-encrypt everything with a new key
```

If `[project]` is omitted, it's derived from the current directory's git remote or name.

### Monorepo support

For monorepos with `package.json` workspaces, use `--workspaces` (`-w`) from the repo root:

```bash
cd ~/myapp               # has package.json with "workspaces": ["apps/*", "packages/*"]
secrets push -w          # encrypts .env* from root + each workspace
secrets pull -w          # decrypts into root + each workspace directory
```

Secrets are stored as `<monorepo>/<workspace-path>/` in `~/.secrets/`:

```
~/.secrets/
  myapp/
    .env.age                    # root
    apps/web/.env.staging.age   # workspace
    apps/api/.env.age           # workspace
```

Requires `jq` (`brew install jq`).

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
bats test/secrets.bats    # 25 tests
```
