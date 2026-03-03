#!/bin/bash
set -euo pipefail

# Migrate existing projects to GitHub deploy workflow.
# For each project: adds .github/workflows/deploy.yml, commits it,
# adds origin remote, force-pushes to GitHub, sets DREAMCOMPUTE_DEPLOY_KEY secret.

DEPLOY_KEY_PATH="$HOME/.ssh/id_ed25519"
GH_USER="leomancini"
SERVER_HOST="leo@root.noshado.ws"

# Discover services and react apps from the filesystem
mapfile -t SERVICES < <(find /home/leo/services -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
mapfile -t REACT_APPS < <(find /home/leo/react-apps -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

SUCCEEDED=()
SKIPPED=()
FAILED=()

generate_workflow() {
  local name="$1"
  local remote_path="$2"
  cat <<EOF
name: Deploy to dreamcompute-leo

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up SSH
        run: |
          mkdir -p ~/.ssh
          echo "\${{ secrets.DREAMCOMPUTE_DEPLOY_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          ssh-keyscan root.noshado.ws >> ~/.ssh/known_hosts

      - name: Deploy
        run: |
          git remote add dreamcompute-leo ${SERVER_HOST}:${remote_path}
          git push dreamcompute-leo main
EOF
}

migrate_project() {
  local name="$1"
  local local_path="$2"
  local remote_path="$3"

  echo ""
  echo "========================================="
  echo "Migrating: $name"
  echo "  Local:  $local_path"
  echo "  Remote: $remote_path"
  echo "========================================="

  # Check local directory exists
  if [ ! -d "$local_path" ]; then
    echo "  SKIP: Local directory does not exist"
    SKIPPED+=("$name (no local dir)")
    return
  fi

  # Check GitHub repo exists
  if ! gh repo view "${GH_USER}/${name}" --json name &>/dev/null; then
    echo "  SKIP: GitHub repo ${GH_USER}/${name} does not exist"
    SKIPPED+=("$name (no GitHub repo)")
    return
  fi

  cd "$local_path"

  # Check if already fully migrated (has both workflow and origin remote)
  local has_workflow=false
  local has_origin=false

  if [ -f ".github/workflows/deploy.yml" ]; then
    has_workflow=true
  fi

  if git remote get-url origin &>/dev/null; then
    has_origin=true
  fi

  if $has_workflow && $has_origin; then
    echo "  SKIP: Already has deploy.yml and origin remote"
    SKIPPED+=("$name (already migrated)")
    return
  fi

  # Determine the main branch name
  local main_branch
  main_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")

  # Create workflow file if missing
  if ! $has_workflow; then
    echo "  Creating .github/workflows/deploy.yml..."
    mkdir -p .github/workflows
    generate_workflow "$name" "$remote_path" > .github/workflows/deploy.yml

    git add .github/workflows/deploy.yml
    git commit -m "Add GitHub Actions deploy workflow" --no-gpg-sign
    echo "  Committed workflow file."
  else
    echo "  Workflow file already exists, skipping creation."
  fi

  # Add origin remote if missing
  if ! $has_origin; then
    echo "  Adding origin remote..."
    git remote add origin "git@github.com:${GH_USER}/${name}.git"
  else
    echo "  Origin remote already set."
  fi

  # Force-push to GitHub (DreamCompute is authoritative)
  echo "  Force-pushing ${main_branch} to GitHub..."
  if ! git push --force origin "${main_branch}:main" 2>&1; then
    echo "  FAILED: Force-push failed"
    FAILED+=("$name (push failed)")
    return
  fi

  # Set DREAMCOMPUTE_DEPLOY_KEY secret
  echo "  Setting DREAMCOMPUTE_DEPLOY_KEY secret..."
  if ! gh secret set DREAMCOMPUTE_DEPLOY_KEY --repo "${GH_USER}/${name}" < "$DEPLOY_KEY_PATH" 2>&1; then
    echo "  FAILED: Could not set secret"
    FAILED+=("$name (secret failed)")
    return
  fi

  echo "  SUCCESS"
  SUCCEEDED+=("$name")
}

echo "Starting migration of $(( ${#SERVICES[@]} + ${#REACT_APPS[@]} )) projects..."
echo ""

# Migrate services
for name in "${SERVICES[@]}"; do
  migrate_project "$name" "/home/leo/services/${name}" "/home/leo/services/${name}"
done

# Migrate react apps
for name in "${REACT_APPS[@]}"; do
  migrate_project "$name" "/home/leo/react-apps/${name}" "/home/leo/react-apps/${name}"
done

# Summary
echo ""
echo "========================================="
echo "MIGRATION COMPLETE"
echo "========================================="
echo ""
echo "Succeeded (${#SUCCEEDED[@]}):"
for s in "${SUCCEEDED[@]+"${SUCCEEDED[@]}"}"; do
  echo "  - $s"
done
echo ""
echo "Skipped (${#SKIPPED[@]}):"
for s in "${SKIPPED[@]+"${SKIPPED[@]}"}"; do
  echo "  - $s"
done
echo ""
echo "Failed (${#FAILED[@]}):"
for s in "${FAILED[@]+"${FAILED[@]}"}"; do
  echo "  - $s"
done
