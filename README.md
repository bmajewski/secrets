# secrets

A command-line tool for sharing secret files (API keys, database passwords, tokens) between your machines and teammates — without ever putting them in your project's git history.

## The problem

Most projects have files like `.env`, `.env.staging`, or `.dev.vars` that contain sensitive credentials. These files should never be committed to your project's git repository because:

- Anyone with access to the repo can see them (even if you delete them later — git keeps history forever)
- Automated tools, CI pipelines, and compromised dependencies can read plaintext files from your project directory
- There's no safe built-in way to share these files between your laptop, your desktop, or a teammate's machine

People end up sharing secrets over Slack, email, or sticky notes. When a key changes, someone forgets to update, and things break.

## What this tool does

`secrets` encrypts your secret files and stores them in a separate, private git repository. Only someone with the encryption key can read them.

```diagram
Your project (e.g. ~/myapp/)           Your secrets store (~/.secrets/)
┌──────────────────────────┐          ┌──────────────────────────┐
│ .env          (plaintext)│──encrypt─▶│ myapp/.env.age (encrypted)│──sync──▶ GitHub (private)
│ .env.staging  (plaintext)│          │ myapp/.env.staging.age    │
│ .dev.vars     (plaintext)│          │ key.txt (never uploaded)  │
└──────────────────────────┘          └──────────────────────────┘
```

- **Encrypted at rest** — files are encrypted with [age](https://github.com/FiloSottile/age), a modern encryption tool. Without the key, the files are unreadable.
- **Synced via git** — the encrypted files are stored in a private git repository that syncs between machines. You never interact with this repo directly — `secrets push` and `secrets pull` handle it.
- **Minimal exposure** — `secrets run` keeps plaintext files on disk only while your command is running, then deletes them automatically.

### What files are tracked

| Pattern | Example | Source |
|---------|---------|--------|
| `.env` | `SECRET_KEY=abc123` | Standard environment file |
| `.env.*` | `.env.staging`, `.env.production` | Environment-specific variants |
| `.dev.vars` | `CF_API_TOKEN=xyz` | Cloudflare Wrangler local secrets |

Files like `.envrc` (direnv) and `.environment-*` are intentionally **not** tracked.

## Prerequisites

- **macOS** (uses Homebrew for installation)
- **git** (already installed on most Macs — type `git --version` to check)
- **age** (the encryption tool — installed in step 1 below)

## Setup

### First machine (one-time setup)

```bash
# 1. Install the encryption tool
brew install age

# 2. Download the secrets tool
#    Replace <you> with your GitHub username or org
git clone git@github.com:<you>/secrets.git ~/dev/secrets

# 3. Make the 'secrets' command available everywhere
#    Add this line to your shell config file (~/.zshrc on Mac):
export PATH="$HOME/dev/secrets:$PATH"
#    Then restart your terminal, or run:
source ~/.zshrc

# 4. Initialize your encrypted secrets store
#    This creates a folder at ~/.secrets/ with your encryption key
secrets init

# 5. Create a PRIVATE repository on GitHub to store your encrypted secrets
#    Go to github.com/new, name it something like 'my-secrets', and make sure
#    "Private" is selected. Then connect it:
cd ~/.secrets
git remote add origin git@github.com:<you>/my-secrets.git
git push -u origin main
```

> **Important:** Step 5 creates a *separate* private repo for your encrypted secrets. This is different from the `secrets` tool repo you cloned in step 2. The tool repo can be public — it contains no secrets. The `~/.secrets/` repo must be private.

### Additional machines

On each new machine (your desktop, a teammate's laptop, etc.):

```bash
# 1. Install prerequisites and the tool (same as steps 1-3 above)
brew install age
git clone git@github.com:<you>/secrets.git ~/dev/secrets
export PATH="$HOME/dev/secrets:$PATH"  # add to ~/.zshrc

# 2. Clone the encrypted secrets repo
git clone git@github.com:<you>/my-secrets.git ~/.secrets

# 3. Copy the encryption key from your first machine
#    This is the only step that requires direct machine-to-machine transfer.
#    Choose one method:
#
#    Option A: AirDrop (Mac to Mac)
#      On your first machine, right-click ~/.secrets/key.txt → Share → AirDrop
#      Save it to ~/.secrets/key.txt on the new machine
#
#    Option B: Secure copy over SSH
#      scp first-machine:~/.secrets/key.txt ~/.secrets/key.txt
#
#    Option C: USB drive
#      Copy key.txt to a USB drive, transfer it, delete from USB after

# 4. Pull your secrets into any project
cd ~/myapp
secrets pull
```

> **The key file (`~/.secrets/key.txt`) is the only thing that needs to be transferred manually.** It never leaves your machines — it's excluded from git, never uploaded, never transmitted over the internet. Anyone with this file can decrypt all your secrets, so treat it like a password.

### Sharing with teammates

To share secrets with a teammate, they need:

1. Access to your private `my-secrets` GitHub repo (add them as a collaborator)
2. A copy of `key.txt` (send it to them directly — AirDrop, USB, or in-person)

Everyone on the team uses the same key. When anyone runs `secrets push`, the encrypted files are updated and everyone else can `secrets pull` to get the latest version.

## Usage

### Daily workflow

```bash
# Start of your work session — pull the latest secrets into your project
cd ~/myapp
secrets pull

# ... code, test, deploy ...

# If you changed any secret files, push the updates
secrets push

# End of session — remove plaintext secrets from disk (optional but recommended)
secrets clear
```

### Command reference

| Command | What it does |
|---------|-------------|
| `secrets init` | Create the `~/.secrets/` repo and generate an encryption key |
| `secrets push` | Encrypt secret files in the current directory and upload them |
| `secrets pull` | Download and decrypt secret files into the current directory |
| `secrets clear` | Delete plaintext secret files from the current directory |
| `secrets run <command>` | Pull secrets, run a command, then clear secrets when it exits |
| `secrets list` | Show all projects that have stored secrets |
| `secrets rm <project>` | Delete a project's secrets from the store |
| `secrets rekey` | Generate a new encryption key and re-encrypt everything |

### Automatic project detection

When you run `secrets push` or `secrets pull` without specifying a project name, the tool figures out which project you're in by:

1. Checking the current directory's git remote (e.g., `origin` → `github.com/you/myapp.git` → `myapp`)
2. Falling back to the directory name (e.g., `/Users/you/myapp` → `myapp`)

You can also specify a name explicitly: `secrets push myapp`.

### Minimizing plaintext exposure

Every second that plaintext secret files sit on disk is a window for a compromised tool or dependency to read them. `secrets run` shrinks that window to only while your command is running:

```bash
secrets run npm start           # .env exists only while dev server is up
secrets run wrangler deploy     # .dev.vars exists only during deploy
```

When the command exits — whether normally, from an error, or from Ctrl-C — the plaintext files are automatically deleted.

This works in `package.json` scripts too, so your whole team gets the protection automatically:

```json
{
  "scripts": {
    "dev": "secrets run react-router dev --port 5173",
    "deploy": "secrets run wrangler deploy"
  }
}
```

Now `npm run dev` pulls secrets, starts the dev server, and clears secrets when you stop it.

### Monorepo support

For projects with multiple packages (monorepos using `package.json` workspaces), add the `-w` flag to operate on all workspaces at once:

```bash
cd ~/myapp                  # has package.json with "workspaces": ["apps/*", "packages/*"]
secrets push -w             # encrypts secrets from root + each workspace
secrets pull -w             # decrypts into root + each workspace directory
secrets clear -w            # clears secrets from root + each workspace
secrets run -w turbo dev    # pull all, run command, clear all on exit
```

Inside `~/.secrets/`, workspace secrets are organized by path:

```shell
~/.secrets/
  myapp/
    .env.age                        # root project secrets
    apps/web/.env.staging.age       # web app workspace
    apps/api/.env.age               # api workspace
```

Requires `jq` (`brew install jq`).

## Safety features

- **`secrets run` auto-clears** — plaintext files are deleted when the command exits, errors, or is interrupted with Ctrl-C
- **Pre-commit hook** — a git hook in `~/.secrets/` prevents accidentally committing plaintext secret files to the encrypted store
- **Key is never uploaded** — `key.txt` is gitignored and never leaves your machine via git
- **Encryption is file-level** — each secret file is independently encrypted. A corrupted file doesn't affect others.

## Key rotation

If you suspect your key has been compromised, or a teammate leaves the team:

```bash
secrets rekey
```

This generates a new key and re-encrypts all secrets. After rekeying:

1. Copy the new `~/.secrets/key.txt` to every machine and teammate
2. Old encrypted files remain in git history (encrypted with the old key, which should be discarded)

For complete rotation with no historical exposure, create a fresh `~/.secrets/` repo.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `SECRETS_DIR` | `~/.secrets` | Override the secrets store location |

## Troubleshooting

**"Key file not found"** — You need `~/.secrets/key.txt`. Either run `secrets init` (first machine) or copy it from a machine that has it.

**"Not initialized"** — Run `secrets init` to create the `~/.secrets/` directory.

**"No secret files found"** — You're in a directory that doesn't have `.env`, `.env.*`, or `.dev.vars` files. Make sure you're in the right project directory.

**"Project not found"** — The project name doesn't match anything in `~/.secrets/`. Run `secrets list` to see what's stored. The name is usually derived from your directory name or git remote.

**"Fast-forward pull failed"** — Someone else pushed secrets while you had local changes. Run `secrets pull` first, then retry your push.

## Development

```bash
# Run the test suite (37 tests)
brew install bats-core
bats test/secrets.bats
```
