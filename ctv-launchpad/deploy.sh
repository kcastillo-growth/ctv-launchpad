#!/usr/bin/env bash
# Deploy ctv-launchpad (static CTV IO builder) to Teflon.
#
#   ./deploy.sh                         first prod deploy
#   ./deploy.sh --keep-secret           prod code change (no secrets; same deploy)
#   ./deploy.sh --staging --keep-secret staging preview
#   ./deploy.sh --staging               staging first deploy
#
# Static-only: no Databricks secrets. --keep-secret is accepted for habit
# compatibility with growth-platform-marketing and is a no-op for secrets.
#
# Do not leave staging in teflon.toml — restore prod name after a staging deploy.

set -u
cd "$(dirname "$0")" || exit 1

page=static/index.html
if [ -f "$page" ]; then
  if command -v md5 >/dev/null 2>&1; then sum=$(md5 -q "$page")
  elif command -v md5sum >/dev/null 2>&1; then sum=$(md5sum "$page" | awk '{print $1}')
  else sum="(no md5 tool)"; fi
  echo "Building from : $(pwd)"
  echo "Page          : $page  $(wc -c < "$page" | tr -d ' ') bytes"
  echo "Page md5      : $sum"
  echo "Page modified : $(date -r "$page" '+%Y-%m-%d %H:%M' 2>/dev/null || echo unknown)"
  echo
else
  echo "No $page in $(pwd) -- wrong folder?" >&2
  exit 1
fi

PROD_APP=ctv-launchpad
STAGING_APP=ctv-launchpad-staging
PORT=8080

KEEP=0
STAGING=0
for arg in "$@"; do
  case "$arg" in
    --keep-secret) KEEP=1 ;;
    --staging) STAGING=1 ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg (want --staging and/or --keep-secret)" >&2
      exit 1
      ;;
  esac
done

if [ "$STAGING" = "1" ]; then
  APP="$STAGING_APP"
  ENV_LABEL=staging
else
  APP="$PROD_APP"
  ENV_LABEL=production
fi

restore_prod_toml(){
  cat > teflon.toml <<EOF
name = "$PROD_APP"
port = $PORT
EOF
}

run_deploy(){
  echo "Deploying $APP ($ENV_LABEL) on port $PORT ..."
  # Static app: no --set-secret. Env only labels staging vs production.
  teflon deploy "$APP" --port "$PORT" --yes \
    --set-env "CTV_LAUNCHPAD_ENV=$ENV_LABEL"
  local rc=$?
  if [ "$STAGING" = "1" ]; then
    restore_prod_toml
    echo "Restored teflon.toml -> name = $PROD_APP (staging deploy must not stick)."
  fi
  return $rc
}

if [ "$KEEP" = "1" ]; then
  echo "No secrets to keep (static app); deploying $APP ($ENV_LABEL)."
else
  echo "First / full deploy of $APP ($ENV_LABEL). No Databricks secrets needed."
fi

echo "Target        : $APP ($ENV_LABEL)"
echo "URL           : https://$APP.tf.int.tubi.io/"
run_deploy || exit 1

echo
echo "Done. Hard-reload the app (Cmd+Shift+R)."
echo "  https://$APP.tf.int.tubi.io/"
echo "  curl -s https://$APP.tf.int.tubi.io/healthz"
if [ "$STAGING" = "1" ]; then
  echo "  Staging banner should read STAGING at the top of the page."
  echo "  When ready for everyone: ./deploy.sh --keep-secret"
fi
echo "Logs: teflon logs $APP"
