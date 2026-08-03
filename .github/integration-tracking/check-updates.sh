#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright Red Hat Inc. and Hibernate Authors
#
# Detects new integration series (Quarkus, WildFly, Spring Boot, ...),
# resolves the Hibernate dependency versions they include,
# and updates a pinned GitHub issue with actionable info.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yml"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECTS_DIR="${REPO_ROOT}/_data/projects"
WORK_DIR="$(mktemp -d)"

trap 'rm -rf "${WORK_DIR}"' EXIT

# ---------------------------------------------------------------------------
# Utility: compare dotted numeric version strings
# Returns 0 if $1 > $2, 1 otherwise
# ---------------------------------------------------------------------------
version_gt() {
    local IFS='.'
    local -a a=($1) b=($2)
    local max=$(( ${#a[@]} > ${#b[@]} ? ${#a[@]} : ${#b[@]} ))
    for (( i=0; i<max; i++ )); do
        local ai="${a[$i]:-0}" bi="${b[$i]:-0}"
        if (( ai > bi )); then return 0; fi
        if (( ai < bi )); then return 1; fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# Extract the maximum tracked version for an integration from all series.yml
# ---------------------------------------------------------------------------
find_max_tracked_version() {
    local integration_id="$1"
    local max_version=""

    while IFS= read -r series_file; do
        local versions
        versions=$(yq "
            .integration_constraints.${integration_id}.version
            | select(. != null)
            | (select(kind == \"scalar\"))
              // (select(kind == \"seq\") | .[] | (.to // .from // .value // .))
              // (.to // .from // .value // .)
        " "$series_file" 2>/dev/null || true)

        while IFS= read -r v; do
            [[ -z "$v" ]] && continue
            if [[ -z "$max_version" ]] || version_gt "$v" "$max_version"; then
                max_version="$v"
            fi
        done <<< "$versions"
    done < <(find "$PROJECTS_DIR" -path '*/releases/*/series.yml' -type f)

    echo "$max_version"
}

# ---------------------------------------------------------------------------
# Extract the first N numeric components from a version string as a "series"
# e.g., "3.38.0" with components=2 -> "3.38"
#        "41.0.0.Final" with components=1 -> "41"
# ---------------------------------------------------------------------------
extract_series() {
    local version="$1"
    local components="$2"
    echo "$version" | grep -oP '\d+' | head -n "$components" | paste -sd '.'
}

# ---------------------------------------------------------------------------
# Generate a POM to check for newer versions of a BOM
# ---------------------------------------------------------------------------
generate_check_pom() {
    local group_id="$1" artifact_id="$2" version="$3" pom_file="$4"
    cat > "$pom_file" << EOF
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <groupId>org.hibernate.tracking</groupId>
    <artifactId>version-checker</artifactId>
    <version>1.0.0</version>
    <packaging>pom</packaging>
    <dependencies>
        <dependency>
            <groupId>${group_id}</groupId>
            <artifactId>${artifact_id}</artifactId>
            <version>${version}</version>
            <type>pom</type>
        </dependency>
    </dependencies>
</project>
EOF
}

# ---------------------------------------------------------------------------
# Generate a POM to resolve Hibernate dependencies through a BOM
# ---------------------------------------------------------------------------
generate_resolve_pom() {
    local group_id="$1" artifact_id="$2" version="$3" pom_file="$4"
    shift 4
    # Remaining args are artifact coordinates: "groupId:artifactId" ...

    cat > "$pom_file" << EOF
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <groupId>org.hibernate.tracking</groupId>
    <artifactId>bom-resolver</artifactId>
    <version>1.0.0</version>
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>${group_id}</groupId>
                <artifactId>${artifact_id}</artifactId>
                <version>${version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
    <dependencies>
EOF

    for artifact_coord in "$@"; do
        local dep_group dep_artifact
        dep_group="${artifact_coord%%:*}"
        dep_artifact="${artifact_coord##*:}"
        cat >> "$pom_file" << EOF
        <dependency>
            <groupId>${dep_group}</groupId>
            <artifactId>${dep_artifact}</artifactId>
        </dependency>
EOF
    done

    cat >> "$pom_file" << EOF
    </dependencies>
</project>
EOF
}

# ---------------------------------------------------------------------------
# Check for a newer version of a BOM using versions-maven-plugin
# Returns the latest version or empty string if up to date
# ---------------------------------------------------------------------------
check_for_update() {
    local group_id="$1" artifact_id="$2" current_version="$3"

    local pom_file="${WORK_DIR}/check-pom.xml"
    generate_check_pom "$group_id" "$artifact_id" "$current_version" "$pom_file"

    local mvn_output
    if ! mvn_output=$(mvn -f "$pom_file" -B \
        versions:display-dependency-updates \
        -DprocessDependencyManagement=false \
        2>&1); then
        echo "  WARNING: Maven version check failed for ${group_id}:${artifact_id}" >&2
        return 1
    fi

    echo "$mvn_output" \
        | grep "${group_id}:${artifact_id}" \
        | grep -oP '\->\s*\K\S+' \
        || true
}

# ---------------------------------------------------------------------------
# Resolve Hibernate dependency versions through a BOM
# Output: lines of "project artifact_coord resolved_version"
# ---------------------------------------------------------------------------
resolve_hibernate_versions() {
    local integration_id="$1" group_id="$2" artifact_id="$3" version="$4"

    local resolve_count
    resolve_count=$(yq -r ".integrations.${integration_id}.resolve | length" "$CONFIG_FILE")

    local artifact_coords=()
    local projects=()
    for (( i=0; i<resolve_count; i++ )); do
        artifact_coords+=("$(yq -r ".integrations.${integration_id}.resolve[$i].artifact" "$CONFIG_FILE")")
        projects+=("$(yq -r ".integrations.${integration_id}.resolve[$i].project" "$CONFIG_FILE")")
    done

    local pom_file="${WORK_DIR}/resolve-${integration_id}.xml"
    generate_resolve_pom "$group_id" "$artifact_id" "$version" "$pom_file" "${artifact_coords[@]}"

    local tree_output
    if ! tree_output=$(mvn -f "$pom_file" dependency:tree 2>&1); then
        echo "  WARNING: Maven dependency resolution failed for ${group_id}:${artifact_id}:${version}" >&2
        return 1
    fi

    for (( i=0; i<resolve_count; i++ )); do
        local coord="${artifact_coords[$i]}"
        local project="${projects[$i]}"
        local dep_group="${coord%%:*}"
        local dep_artifact="${coord##*:}"

        local escaped_group="${dep_group//./\\.}"
        local resolved
        resolved=$(echo "$tree_output" \
            | grep -oP "${escaped_group}:${dep_artifact}:jar:\K[^:]+" \
            | head -1 || true)

        if [[ -n "$resolved" ]]; then
            echo "${project} ${coord} ${resolved}"
        fi
    done
}

# ---------------------------------------------------------------------------
# Find the series.yml file that should be updated for a given Hibernate
# project and resolved version
# ---------------------------------------------------------------------------
find_series_file() {
    local project="$1" resolved_version="$2"
    local series
    series=$(extract_series "$resolved_version" 2)
    local series_file="${PROJECTS_DIR}/${project}/releases/${series}/series.yml"
    if [[ -f "$series_file" ]]; then
        echo "$series_file"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    local issue_body="# Integration Version Tracking"$'\n\n'
    issue_body+="> Last checked: $(date -u +%Y-%m-%d)"$'\n'
    local integration_ids
    integration_ids=$(yq -r '.integrations | keys | .[]' "$CONFIG_FILE")

    while IFS= read -r integration_id; do
        local display_name group_id artifact_id series_components
        display_name=$(yq -r ".integrations.${integration_id}.display_name" "$CONFIG_FILE")
        group_id=$(yq -r ".integrations.${integration_id}.bom_group_id" "$CONFIG_FILE")
        artifact_id=$(yq -r ".integrations.${integration_id}.bom_artifact_id" "$CONFIG_FILE")
        series_components=$(yq -r ".integrations.${integration_id}.series_components" "$CONFIG_FILE")

        echo "Checking ${display_name}..."

        local max_tracked
        max_tracked=$(find_max_tracked_version "$integration_id")
        if [[ -z "$max_tracked" ]]; then
            echo "  No tracked version found for ${integration_id}, skipping"
            issue_body+=$'\n'"## ${display_name}"$'\n'
            issue_body+="No tracked versions found in series.yml files"$'\n'
            continue
        fi

        echo "  Max tracked series: ${max_tracked}"

        # We need a full Maven version, not just the series.
        # Append .0 components + qualifier to match Maven Central artifact versions.
        local check_version="$max_tracked"
        # Pad with .0 until we have at least 3 components (Maven convention)
        local dot_count
        dot_count=$(echo "$check_version" | tr -cd '.' | wc -c)
        while (( dot_count < 2 )); do
            check_version="${check_version}.0"
            dot_count=$((dot_count + 1))
        done

        local latest
        if ! latest=$(check_for_update "$group_id" "$artifact_id" "$check_version"); then
            issue_body+=$'\n'"## ${display_name}"$'\n'
            issue_body+="**Error**: failed to check for updates"$'\n'
            continue
        fi

        issue_body+=$'\n'"## ${display_name}"$'\n'

        if [[ -z "$latest" ]]; then
            echo "  Up to date"
            issue_body+="Up to date (series \`${max_tracked}\` is the latest)"$'\n'
            continue
        fi

        local latest_series
        latest_series=$(extract_series "$latest" "$series_components")
        echo "  New version available: ${latest} (series ${latest_series})"

        issue_body+="**New series \`${latest_series}\` detected** (latest: \`${latest}\`)"$'\n\n'

        # Resolve Hibernate dependencies
        echo "  Resolving Hibernate dependencies..."
        local resolved_lines
        if ! resolved_lines=$(resolve_hibernate_versions "$integration_id" "$group_id" "$artifact_id" "$latest"); then
            issue_body+="**Error**: failed to resolve Hibernate dependencies"$'\n'
            continue
        fi

        if [[ -n "$resolved_lines" ]]; then
            issue_body+="| Hibernate Project | Version | Series |"$'\n'
            issue_body+="|---|---|---|"$'\n'

            local suggested_updates=""
            while IFS=' ' read -r project coord resolved_version; do
                local hibernate_series
                hibernate_series=$(extract_series "$resolved_version" 2)
                local project_display="${project^}"
                [[ "$project" == "orm" ]] && project_display="ORM"
                issue_body+="| ${project_display} | ${resolved_version} | ${hibernate_series} |"$'\n'

                local series_file
                series_file=$(find_series_file "$project" "$resolved_version")
                if [[ -n "$series_file" ]]; then
                    local rel_path="${series_file#"${REPO_ROOT}/"}"
                    suggested_updates+="- \`${rel_path}\` — extend ${integration_id} \`to: '${latest_series}'\`"$'\n'
                fi
            done <<< "$resolved_lines"

            if [[ -n "$suggested_updates" ]]; then
                issue_body+=$'\n'"**Suggested updates:**"$'\n'
                issue_body+="$suggested_updates"
            fi
        else
            issue_body+="Could not resolve Hibernate dependencies from this BOM."$'\n'
        fi
    done <<< "$integration_ids"

    echo ""
    echo "=== Issue Body ==="
    echo "$issue_body"
    echo "=================="

    update_github_issue "$issue_body"
}

# ---------------------------------------------------------------------------
# Update the tracking issue if TRACKING_ISSUE_NUMBER is set
# ---------------------------------------------------------------------------
update_github_issue() {
    local body="$1"

    if [[ -z "${TRACKING_ISSUE_NUMBER:-}" ]]; then
        echo "TRACKING_ISSUE_NUMBER not set, skipping issue update"
        return
    fi

    echo "Updating issue #${TRACKING_ISSUE_NUMBER}"
    gh issue edit "$TRACKING_ISSUE_NUMBER" --body "$body"
}

main "$@"
