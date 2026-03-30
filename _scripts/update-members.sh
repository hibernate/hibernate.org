#!/bin/bash -e

function rest_api_call() {
  endpoint=$1
  shift
  curl --fail -s -S -L \
    --variable %GITHUB_TOKEN \
    -H "Accept: application/vnd.github+json" \
    --expand-header "Authorization: Bearer {{GITHUB_TOKEN}}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com$endpoint" "${@}"
}

jq -s 'add | [reduce .[] as $o ({}; .[$o["login"] | tostring] += $o ) | .[]] | sort_by( .login ) | [ .[] | select( .public ) | { login, avatar_url, html_url, "alumnus": (.alumnus // false) } ]' \
  <( \
    rest_api_call /orgs/hibernate/teams/alumni/members?per_page=100 \
      | jq '[.[] + {"alumnus": true}]' \
  ) \
  <( \
    rest_api_call /orgs/hibernate/public_members?per_page=100 \
      | jq '[.[] + {"public": true}]' \
  ) \
  > _data/members.json
