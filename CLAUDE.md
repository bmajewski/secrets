# secrets

Encrypted env file sync between machines using `age` key-file encryption + a private git repo.

## Quick Start

```bash
brew install age
./secrets init                    # Create ~/.secrets repo + generate age key
cd ~/my-project && ./secrets push # Encrypt .env* files, commit, push
# On other machine:
cd ~/my-project && ./secrets pull # Pull + decrypt .env* files
```

## Testing

```bash
brew install bats-core
bats test/secrets.bats
```

## Architecture

Single bash script (`secrets`) with subcommands: init, push, pull, list, rm, rekey.

- Encryption: `age` with key files (not passphrases — age passphrases are non-scriptable)
- Storage: Private git repo at `~/.secrets/`
- Convention: Globs `.env` and `.env.*` (not `.envrc`, `.environment-*`)
- Safety: Pre-commit hook rejects plaintext `.env` files

## Project Structure

```
secrets              # CLI script (~300 lines bash)
hooks/pre-commit     # Pre-commit hook template
test/
  secrets.bats       # bats-core test suite (20 tests)
  test_helper.bash   # Shared setup/teardown
README.md            # User-facing documentation
CLAUDE.md            # This file
```

## Key file

`~/.secrets/key.txt` is the age identity (private key). It is gitignored and must be copied manually to each machine once.

## Environment variable

`SECRETS_DIR` overrides the default `~/.secrets` location (useful for testing).
