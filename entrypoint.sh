#!/usr/bin/env bash
set -eu -o pipefail

: "${GITHUB_APP_ID:?}"
: "${GITHUB_APP_INSTALLATION_ID:?}"
: "${GITHUB_APP_PRIVATE_KEY:?}"
: "${GH_URL:?}"
: "${REGISTRATION_TOKEN_API_URL:?}"

RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,aca}"
API="${GITHUB_API_URL:-https://api.github.com}"
RUNNER_NAME="${RUNNER_NAME:-aca-runner-$(hostname)}"

b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

# 1. Build a JWT signed with the app's private key
KEY_FILE="$(mktemp)"
trap 'rm -f "$KEY_FILE"' EXIT


echo "Signing GitHub App JWT..."
now="$(date +%s)"
header="$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)"
payload="$(printf '{"iat":%s,"exp":%s,"iss":"%s"}' "$((now-60))" "$((now+540))" "${GITHUB_APP_ID}" | b64url)"

printf '%s' "${GITHUB_APP_PRIVATE_KEY}" | base64 -d > "$KEY_FILE"
signature="$(printf '%s' "${header}.${payload}" | openssl dgst -sha256 -sign "${KEY_FILE}" -binary | b64url)"
jwt="${header}.${payload}.${signature}"

# 2. Exchange JWT for an installation access token
echo "Exchanging JWT for an installation token..."
INSTALL_TOKEN="$(curl -fsSL --retry 3 --retry-connrefused -X POST \
  -H "Authorization: Bearer ${jwt}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${API}/app/installations/${GITHUB_APP_INSTALLATION_ID}/access_tokens" | jq -r '.token')"

if [ -z "${INSTALL_TOKEN}" ] || [ "${INSTALL_TOKEN}" = "null" ]; then
  echo "ERROR: failed to obtain an installation token. Check App ID, installation ID, and private key." >&2
  exit 1
fi


# 3. Get a runner registration token
REGISTRATION_TOKEN="$(curl -fsSL --retry 3 --retry-connrefused -X POST \
  -H "Authorization: Bearer ${INSTALL_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${REGISTRATION_TOKEN_API_URL}" | jq -r '.token')"



if [ -z "${REGISTRATION_TOKEN}" ] || [ "${REGISTRATION_TOKEN}" = "null" ]; then
  echo "ERROR: failed to obtain a registration token." >&2
  exit 1
fi

# 4. Register as ephemeral and run exactly one job
./config.sh \
  --url "${GH_URL}" \
  --token "${REGISTRATION_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --labels "${RUNNER_LABELS}" \
  --unattended \
  --ephemeral \
  --replace

echo "Starting the runner..."
exec ./run.sh