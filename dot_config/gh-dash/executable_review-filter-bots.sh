#!/usr/bin/env bash
set -euo pipefail

jq '[.[] | select(
  (.author.login // "" | ascii_downcase) as $author
  | [
      "renovate",
      "renovate[bot]",
      "dependabot",
      "dependabot[bot]",
      "github-actions",
      "github-actions[bot]",
      "changesets",
      "changesets[bot]",
      "changeset-bot",
      "changeset-bot[bot]",
      "greenkeeper",
      "greenkeeper[bot]",
      "snyk-bot",
      "imgbot",
      "imgbot[bot]",
      "codecov",
      "codecov[bot]",
      "allcontributors",
      "allcontributors[bot]",
      "semantic-release-bot",
      "release-please",
      "release-please[bot]"
    ]
  | index($author)
  | not
)]'
