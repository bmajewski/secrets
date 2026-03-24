#!/usr/bin/env bats

load test_helper

# ─── init ──────────────────────────────────────────────────────────────

@test "init creates repo with key and gitignore" {
  run "$SECRETS_BIN" init
  [ "$status" -eq 0 ]
  [ -d "$SECRETS_DIR/.git" ]
  [ -f "$SECRETS_DIR/key.txt" ]
  [ -f "$SECRETS_DIR/.gitignore" ]
  grep -q "key.txt" "$SECRETS_DIR/.gitignore"
  grep -qF '!**/.env.*.age' "$SECRETS_DIR/.gitignore"
}

@test "init installs pre-commit hook" {
  run "$SECRETS_BIN" init
  [ "$status" -eq 0 ]
  [ -x "$SECRETS_DIR/.git/hooks/pre-commit" ]
}

@test "init warns if already initialized" {
  "$SECRETS_BIN" init >/dev/null 2>&1
  local key_before
  key_before=$(cat "$SECRETS_DIR/key.txt")

  run "$SECRETS_BIN" init
  [ "$status" -eq 1 ]
  [[ "$output" == *"Already initialized"* ]]

  # Key must not be overwritten
  local key_after
  key_after=$(cat "$SECRETS_DIR/key.txt")
  [ "$key_before" = "$key_after" ]
}

@test "init fails without age" {
  # Create a temp PATH without age
  local fake_path="$TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_path"
  ln -s "$(which git)" "$fake_path/git"
  ln -s "$(which bash)" "$fake_path/bash"
  ln -s "$(which mkdir)" "$fake_path/mkdir"
  ln -s "$(which cat)" "$fake_path/cat"
  ln -s "$(which chmod)" "$fake_path/chmod"
  ln -s "$(which cp)" "$fake_path/cp"
  ln -s "$(which basename)" "$fake_path/basename"
  ln -s "$(which dirname)" "$fake_path/dirname"
  ln -s "$(which cd)" "$fake_path/cd" 2>/dev/null || true

  run env PATH="$fake_path" "$SECRETS_BIN" init
  [ "$status" -eq 1 ]
  [[ "$output" == *"age"* ]]
}

# ─── push ──────────────────────────────────────────────────────────────

@test "push encrypts .env files" {
  init_with_remote
  create_project_dir testproj

  run "$SECRETS_BIN" push testproj
  [ "$status" -eq 0 ]
  [ -f "$SECRETS_DIR/testproj/.env.age" ]
  [ -f "$SECRETS_DIR/testproj/.env.staging.age" ]
}

@test "push errors with no .env files" {
  init_with_remote
  mkdir -p "$WORK_DIR/empty"
  cd "$WORK_DIR/empty"

  run "$SECRETS_BIN" push testproj
  [ "$status" -eq 1 ]
  [[ "$output" == *"No .env"* ]]
}

@test "push errors with missing key" {
  init_with_remote
  create_project_dir testproj
  rm "$SECRETS_DIR/key.txt"

  run "$SECRETS_BIN" push testproj
  [ "$status" -eq 1 ]
  [[ "$output" == *"Key file"* ]]
}

@test "push derives project name from dirname" {
  init_with_remote
  create_project_dir myproject
  # Don't pass explicit project name
  run "$SECRETS_BIN" push
  [ "$status" -eq 0 ]
  [ -d "$SECRETS_DIR/myproject" ]
}

@test "push succeeds on repeated push (age is non-deterministic)" {
  init_with_remote
  create_project_dir testproj

  "$SECRETS_BIN" push testproj >/dev/null 2>&1
  # Push again — age produces different ciphertext each time, so this creates a new commit
  run "$SECRETS_BIN" push testproj
  [ "$status" -eq 0 ]
}

# ─── pull ──────────────────────────────────────────────────────────────

@test "pull decrypts files correctly" {
  init_with_remote
  create_project_dir testproj
  "$SECRETS_BIN" push testproj >/dev/null 2>&1

  # Pull into a different directory
  local pull_dir="$WORK_DIR/pull-target"
  mkdir -p "$pull_dir"
  cd "$pull_dir"

  run "$SECRETS_BIN" pull testproj
  [ "$status" -eq 0 ]
  [ -f "$pull_dir/.env" ]
  [ -f "$pull_dir/.env.staging" ]
  [ "$(cat "$pull_dir/.env")" = "SECRET_KEY=abc123" ]
  [ "$(cat "$pull_dir/.env.staging")" = "DB_HOST=staging.db.example.com" ]
}

@test "pull errors for nonexistent project" {
  init_with_remote

  run "$SECRETS_BIN" pull nonexistent
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "pull errors with missing key" {
  init_with_remote
  create_project_dir testproj
  "$SECRETS_BIN" push testproj >/dev/null 2>&1
  rm "$SECRETS_DIR/key.txt"

  local pull_dir="$WORK_DIR/pull-target"
  mkdir -p "$pull_dir"
  cd "$pull_dir"

  run "$SECRETS_BIN" pull testproj
  [ "$status" -eq 1 ]
  [[ "$output" == *"Key file"* ]]
}

@test "pull overwrites existing files" {
  init_with_remote
  create_project_dir testproj
  "$SECRETS_BIN" push testproj >/dev/null 2>&1

  local pull_dir="$WORK_DIR/pull-target"
  mkdir -p "$pull_dir"
  echo "OLD_VALUE=stale" > "$pull_dir/.env"
  cd "$pull_dir"

  run "$SECRETS_BIN" pull testproj
  [ "$status" -eq 0 ]
  [ "$(cat "$pull_dir/.env")" = "SECRET_KEY=abc123" ]
}

@test "pull reinstalls missing pre-commit hook" {
  init_with_remote
  create_project_dir testproj
  "$SECRETS_BIN" push testproj >/dev/null 2>&1

  # Remove the hook
  rm -f "$SECRETS_DIR/.git/hooks/pre-commit"
  [ ! -f "$SECRETS_DIR/.git/hooks/pre-commit" ]

  local pull_dir="$WORK_DIR/pull-target"
  mkdir -p "$pull_dir"
  cd "$pull_dir"

  run "$SECRETS_BIN" pull testproj
  [ "$status" -eq 0 ]
  [ -x "$SECRETS_DIR/.git/hooks/pre-commit" ]
  [[ "$output" == *"Reinstalled"* ]]
}

# ─── list ──────────────────────────────────────────────────────────────

@test "list shows projects and files" {
  init_with_remote
  create_project_dir projA
  "$SECRETS_BIN" push projA >/dev/null 2>&1
  create_project_dir projB
  "$SECRETS_BIN" push projB >/dev/null 2>&1

  run "$SECRETS_BIN" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"projA"* ]]
  [[ "$output" == *"projB"* ]]
}

@test "list shows empty message" {
  "$SECRETS_BIN" init >/dev/null 2>&1

  run "$SECRETS_BIN" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"No projects"* ]]
}

# ─── rm ────────────────────────────────────────────────────────────────

@test "rm removes project from repo" {
  init_with_remote
  create_project_dir testproj
  "$SECRETS_BIN" push testproj >/dev/null 2>&1
  [ -d "$SECRETS_DIR/testproj" ]

  run "$SECRETS_BIN" rm testproj
  [ "$status" -eq 0 ]
  [ ! -d "$SECRETS_DIR/testproj" ]
}

@test "rm errors for nonexistent project" {
  init_with_remote

  run "$SECRETS_BIN" rm nonexistent
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

# ─── pre-commit hook ──────────────────────────────────────────────────

@test "pre-commit blocks plaintext env files" {
  init_with_remote
  cd "$SECRETS_DIR"

  echo "LEAKED=true" > .env.test
  git add -f .env.test

  run git commit -m "should fail"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Plaintext"* ]]
}

@test "pre-commit allows .age files" {
  init_with_remote
  cd "$SECRETS_DIR"

  mkdir -p testproj
  echo "encrypted-blob" > testproj/.env.test.age
  git add testproj/.env.test.age

  run git commit -m "should succeed"
  [ "$status" -eq 0 ]
}

# ─── workspaces ────────────────────────────────────────────────────────

# Helper: create a monorepo with package.json workspaces
create_monorepo() {
  local dir="$WORK_DIR/myapp"
  mkdir -p "$dir/apps/web" "$dir/apps/api" "$dir/packages/auth"

  cat > "$dir/package.json" << 'PKGJSON'
{
  "name": "myapp",
  "workspaces": ["apps/*", "packages/*"]
}
PKGJSON

  # Root env
  echo "ROOT_SECRET=top" > "$dir/.env"
  # Workspace envs
  echo "WEB_DB=webdb" > "$dir/apps/web/.env.staging"
  echo "API_KEY=abc" > "$dir/apps/api/.env"
  # packages/auth has no .env — should be skipped silently

  # Init a git repo so derive_project_name can use dirname
  git init "$dir" >/dev/null 2>&1
  echo "$dir"
}

@test "push --workspaces encrypts root and workspace env files" {
  init_with_remote
  local mono
  mono=$(create_monorepo)
  cd "$mono"

  run "$SECRETS_BIN" push --workspaces
  [ "$status" -eq 0 ]

  # Root env
  [ -f "$SECRETS_DIR/myapp/.env.age" ]
  # Workspace envs
  [ -f "$SECRETS_DIR/myapp/apps/web/.env.staging.age" ]
  [ -f "$SECRETS_DIR/myapp/apps/api/.env.age" ]
  # packages/auth should NOT have a dir (no .env files)
  [ ! -d "$SECRETS_DIR/myapp/packages/auth" ]
}

@test "pull --workspaces decrypts into correct directories" {
  init_with_remote
  local mono
  mono=$(create_monorepo)
  cd "$mono"
  "$SECRETS_BIN" push --workspaces >/dev/null 2>&1

  # Remove the original env files
  rm "$mono/.env" "$mono/apps/web/.env.staging" "$mono/apps/api/.env"

  run "$SECRETS_BIN" pull --workspaces
  [ "$status" -eq 0 ]

  # Verify decrypted into correct locations
  [ "$(cat "$mono/.env")" = "ROOT_SECRET=top" ]
  [ "$(cat "$mono/apps/web/.env.staging")" = "WEB_DB=webdb" ]
  [ "$(cat "$mono/apps/api/.env")" = "API_KEY=abc" ]
}

@test "push --workspaces errors without package.json" {
  init_with_remote
  mkdir -p "$WORK_DIR/nopkg"
  cd "$WORK_DIR/nopkg"

  run "$SECRETS_BIN" push --workspaces
  [ "$status" -eq 1 ]
  [[ "$output" == *"No package.json"* ]]
}

@test "push --workspaces errors without workspaces field" {
  init_with_remote
  mkdir -p "$WORK_DIR/nows"
  echo '{"name": "nows"}' > "$WORK_DIR/nows/package.json"
  cd "$WORK_DIR/nows"

  run "$SECRETS_BIN" push --workspaces
  [ "$status" -eq 1 ]
  [[ "$output" == *"No workspaces"* ]]
}

@test "push --workspaces errors when no env files anywhere" {
  init_with_remote
  local dir="$WORK_DIR/empty-mono"
  mkdir -p "$dir/apps/web" "$dir/packages/lib"
  cat > "$dir/package.json" << 'EOF'
{"workspaces": ["apps/*", "packages/*"]}
EOF
  git init "$dir" >/dev/null 2>&1
  cd "$dir"

  run "$SECRETS_BIN" push --workspaces
  [ "$status" -eq 1 ]
  [[ "$output" == *"No .env files"* ]]
}
