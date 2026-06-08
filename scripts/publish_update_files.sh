#!/usr/bin/env bash
set -euo pipefail

dmg_path="${1:?Usage: publish_update_files.sh DMG_PATH FEED_PATH}"
feed_path="${2:?Usage: publish_update_files.sh DMG_PATH FEED_PATH}"
publish_target="${UPDATE_PUBLISH_TARGET:-github}"

require_file() {
  local path="$1"
  local label="$2"

  if [ ! -f "$path" ]; then
    echo "::error::$label not found at $path"
    exit 1
  fi
}

require_env() {
  local name="$1"
  local target="$2"

  if [ -z "${!name:-}" ]; then
    echo "::error::$name is required when UPDATE_PUBLISH_TARGET=$target."
    exit 1
  fi
}

publish_cloudflare_pages() {
  require_env UPDATE_BASE_URL cloudflare_pages
  require_env CLOUDFLARE_PAGES_PROJECT cloudflare_pages
  require_env CLOUDFLARE_PAGES_BRANCH cloudflare_pages
  require_env CLOUDFLARE_API_TOKEN cloudflare_pages
  require_env CLOUDFLARE_ACCOUNT_ID cloudflare_pages
  require_file "$dmg_path" DMG
  require_file "$feed_path" Appcast

  local site_dir="${UPDATE_SITE_DIR:-build/update-site}"
  rm -rf "$site_dir"
  mkdir -p "$site_dir"
  cp "$dmg_path" "$site_dir/"
  cp "$feed_path" "$site_dir/"

  local project_list
  project_list=$(npx --yes wrangler pages project list --json)
  if ! PROJECT_LIST="$project_list" node <<'NODE'
const payload = JSON.parse(process.env.PROJECT_LIST || '[]');
const projects = Array.isArray(payload)
  ? payload
  : payload.result || payload.projects || payload.items || payload.data || [];
const projectName = process.env.CLOUDFLARE_PAGES_PROJECT;
process.exit(projects.some((project) => project.name === projectName) ? 0 : 1);
NODE
  then
    local create_output
    if ! create_output=$(npx --yes wrangler pages project create \
      "$CLOUDFLARE_PAGES_PROJECT" \
      --production-branch "$CLOUDFLARE_PAGES_BRANCH" 2>&1); then
      if ! grep -qi 'already exists' <<< "$create_output"; then
        printf '%s\n' "$create_output"
        exit 1
      fi
    fi
    printf '%s\n' "$create_output"
  fi

  npx --yes wrangler pages deploy "$site_dir" \
    --project-name "$CLOUDFLARE_PAGES_PROJECT" \
    --branch "$CLOUDFLARE_PAGES_BRANCH" \
    --commit-dirty=true

  echo "Published update files to $UPDATE_BASE_URL"
}

publish_ssh() {
  require_env UPDATE_BASE_URL ssh
  require_env UPDATE_SSH_HOST ssh
  require_env UPDATE_SSH_USER ssh
  require_env UPDATE_SSH_PRIVATE_KEY ssh
  require_env UPDATE_SSH_PATH ssh
  require_file "$dmg_path" DMG
  require_file "$feed_path" Appcast

  local ssh_port="${UPDATE_SSH_PORT:-22}"
  local ssh_dir="$HOME/.ssh"
  local key_path="$ssh_dir/misn_update_publish_key"

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  printf '%s\n' "$UPDATE_SSH_PRIVATE_KEY" > "$key_path"
  chmod 600 "$key_path"

  local known_hosts="$ssh_dir/known_hosts"
  ssh-keyscan -p "$ssh_port" "$UPDATE_SSH_HOST" >> "$known_hosts" 2>/dev/null

  local ssh_args=(
    -p "$ssh_port"
    -i "$key_path"
    -o BatchMode=yes
    -o StrictHostKeyChecking=yes
  )

  local remote="${UPDATE_SSH_USER}@${UPDATE_SSH_HOST}"
  ssh "${ssh_args[@]}" "$remote" "mkdir -p '$UPDATE_SSH_PATH'"
  scp -P "$ssh_port" \
    -i "$key_path" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=yes \
    "$dmg_path" \
    "$feed_path" \
    "$remote:$UPDATE_SSH_PATH/"

  echo "Published update files to $UPDATE_BASE_URL"
}

case "$publish_target" in
  '' | github)
    echo "UPDATE_PUBLISH_TARGET is github; skipping external update publishing."
    ;;
  cloudflare_pages)
    publish_cloudflare_pages
    ;;
  ssh)
    publish_ssh
    ;;
  *)
    echo "::error::Unsupported UPDATE_PUBLISH_TARGET: $publish_target"
    exit 1
    ;;
esac
