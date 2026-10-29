#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright Red Hat Inc. and Hibernate Authors
#
# Detects release announcement blog posts on in.relation.to that are
# not referenced as announcement_url in any of the corresponding
# project's release metadata files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yml"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECTS_DIR="${REPO_ROOT}/_data/projects"
FEED_URL="https://in.relation.to/blog.atom"
LOOKBACK_DAYS=30
WORK_DIR="$(mktemp -d)"

trap 'rm -rf "${WORK_DIR}"' EXIT

# ---------------------------------------------------------------------------
# Fetch the Atom feed and extract release entries from the last N days.
# Output: one line per entry — URL<tab>COMMA_SEPARATED_CATEGORIES<tab>TITLE
# Only entries tagged "Releases" are included.
# ---------------------------------------------------------------------------
fetch_recent_releases() {
    python3 -I - "${WORK_DIR}/feed.atom" "${LOOKBACK_DAYS}" << 'PYEOF'
import sys, xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone

feed_file, lookback_str = sys.argv[1], sys.argv[2]
cutoff = datetime.now(timezone.utc) - timedelta(days=int(lookback_str))
ns = {"atom": "http://www.w3.org/2005/Atom"}

tree = ET.parse(feed_file)
for entry in tree.findall(".//atom:entry", ns):
    published = entry.find("atom:published", ns)
    if published is None:
        continue
    if datetime.fromisoformat(published.text) < cutoff:
        continue
    cats = [c.get("term") for c in entry.findall("atom:category", ns)]
    if "Releases" not in cats:
        continue
    link = entry.find("atom:link", ns)
    if link is None:
        continue
    url = link.get("href", "")
    title = (entry.find("atom:title", ns).text or "").strip()
    project_cats = [c for c in cats if c != "Releases"]
    print(f"{url}\t{','.join(project_cats)}\t{title}")
PYEOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo "Fetching release announcements from ${FEED_URL}..."
    curl -sf "${FEED_URL}" -o "${WORK_DIR}/feed.atom"

    echo "Checking for missing announcement links (last ${LOOKBACK_DAYS} days)..."
    echo ""

    # Build category -> project mapping from config
    declare -A category_to_project
    local project_ids
    project_ids=$(yq -r '.projects | keys | .[]' "$CONFIG_FILE")

    while IFS= read -r project_id; do
        local category
        category=$(yq -r ".projects.${project_id}.blog_category" "$CONFIG_FILE")
        [[ "$category" == "null" || -z "$category" ]] && continue
        category_to_project["$category"]="$project_id"
    done <<< "$project_ids"

    local releases
    releases=$(fetch_recent_releases)

    if [[ -z "$releases" ]]; then
        echo "No release announcements found in the last ${LOOKBACK_DAYS} days."
        return 0
    fi

    local gaps_found=false

    while IFS=$'\t' read -r url categories title; do
        IFS=',' read -ra cat_array <<< "$categories"
        for cat in "${cat_array[@]}"; do
            if [[ -v "category_to_project[$cat]" ]]; then
                local project="${category_to_project[$cat]}"
                local project_dir="${PROJECTS_DIR}/${project}/releases"

                if [[ ! -d "$project_dir" ]]; then
                    echo "  WARNING: No releases directory for project '${project}'" >&2
                    continue
                fi

                if grep -rFq "$url" "$project_dir" 2>/dev/null; then
                    echo "  OK: ${title} (${project})"
                else
                    echo "  MISSING: ${title} (${project})"
                    echo "    Blog post: ${url}"
                    echo "    Not found as announcement_url in _data/projects/${project}/releases/"
                    gaps_found=true
                fi
            fi
        done
    done <<< "$releases"

    echo ""

    if [[ "$gaps_found" == true ]]; then
        echo "FAILURE: One or more release announcements are not linked in release metadata. See details above."
        return 1
    fi

    echo "All recent release announcements are properly linked."
}

main "$@"
