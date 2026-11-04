#!/bin/sh -l

# Retrieve a short lived runner registration token using the PAT
REGISTRATION_TOKEN="$(curl -X POST -fsSL \
  -H 'Accept: application/vnd.github.v3+json' \
  -H "Authorization: Bearer $GITHUB_PAT_TOKEN" \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "$REGISTRATION_TOKEN_API_URL" \
  | jq -r '.token')"


# 4. Register as ephemeral and run exactly one job
./config.sh \
  --url "${GH_URL}" \
  --token "${REGISTRATION_TOKEN}" \
  --labels "${RUNNER_LABELS}" \
  --unattended \
  --ephemeral \
  --replace

./run.sh