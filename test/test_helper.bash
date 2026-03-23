#!/usr/bin/env bash
# Shared setup/teardown for secrets bats tests.
# Creates isolated temp directories for each test — no side effects.

SECRETS_BIN="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)/secrets"

setup() {
  # Check age is available
  if ! command -v age >/dev/null 2>&1; then
    skip "age is not installed"
  fi

  # Create isolated temp environment
  export TEST_TMPDIR
  TEST_TMPDIR=$(mktemp -d)

  # Secrets repo lives in temp
  export SECRETS_DIR="$TEST_TMPDIR/secrets-repo"

  # Working directory for simulating project dirs
  export WORK_DIR="$TEST_TMPDIR/work"
  mkdir -p "$WORK_DIR"

  # Create a bare "remote" repo for push/pull testing
  export REMOTE_DIR="$TEST_TMPDIR/remote.git"
  git init --bare "$REMOTE_DIR" >/dev/null 2>&1
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# Helper: initialize secrets and add remote
init_with_remote() {
  run "$SECRETS_BIN" init
  cd "$SECRETS_DIR"
  git remote add origin "$REMOTE_DIR"
  # Initial commit so push works
  git commit --allow-empty -m "init" >/dev/null 2>&1
  git push -u origin main >/dev/null 2>&1 || git push -u origin master >/dev/null 2>&1
  cd -
}

# Helper: create .env files in a temp project dir and cd into it
create_project_dir() {
  local name="${1:-testproj}"
  local dir="$WORK_DIR/$name"
  mkdir -p "$dir"
  echo "SECRET_KEY=abc123" > "$dir/.env"
  echo "DB_HOST=staging.db.example.com" > "$dir/.env.staging"
  cd "$dir"
}
