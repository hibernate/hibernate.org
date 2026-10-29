#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright Red Hat Inc. and Hibernate Authors
#
# Detects new integration series (Quarkus, WildFly, Spring Boot, ...),
# resolves the Hibernate dependency versions they include,
# and fails if any integration has an untracked series.

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
# Check for a newer series of a BOM using versions-maven-plugin
# Returns the latest version whose series is newer than $tracked_series,
# or empty string if up to date (no newer release, or only patch releases
# of an already-tracked series)
# ---------------------------------------------------------------------------
check_for_update() {
    local group_id="$1" artifact_id="$2" current_version="$3" tracked_series="$4" series_components="$5"

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

    local latest
    latest=$(echo "$mvn_output" \
        | grep "${group_id}:${artifact_id}" \
        | grep -oP '\->\s*\K\S+' \
        || true)

    if [[ -z "$latest" ]]; then
        return 0
    fi

    local latest_series
    latest_series=$(extract_series "$latest" "$series_components")
    if ! version_gt "$latest_series" "$tracked_series"; then
        echo "  Up to date (latest release ${latest} is in tracked series ${tracked_series})" >&2
        return 0
    fi

    echo "$latest"
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
# Discover Hibernate Validator bundles in the Open Liberty repo.
# Uses GitHub code search to find bnd.bnd files referencing hibernate-validator,
# then filters to core bundles (excludes CDI wrappers).
# ---------------------------------------------------------------------------
discover_liberty_hv_bundles() {
    local github_repo="$1"
    local api_output
    if ! api_output=$(gh api "search/code?q=org.hibernate.validator+repo:${github_repo}+filename:bnd.bnd" \
        --jq '.items[].path' 2>&1); then
        echo "  WARNING: Could not discover bundles via code search: ${api_output}" >&2
        echo "  Checking configured paths only" >&2
        return 1
    fi
    echo "$api_output" \
        | grep 'hibernate\.validator' \
        | grep -v '\.cdi' \
        || true
}

# ---------------------------------------------------------------------------
# Check Liberty for Hibernate Validator version updates.
# 1. Discovers all HV bundles in the repo (detects new beanValidation features)
# 2. Checks each configured bundle for constraint coverage
# 3. Checks if the latest Liberty release is newer than tracked 'to:' bounds
# ---------------------------------------------------------------------------
check_liberty_integration() {
    local integration_id="$1"

    local display_name github_repo
    display_name=$(yq -r ".integrations.${integration_id}.display_name" "$CONFIG_FILE")
    github_repo=$(yq -r ".integrations.${integration_id}.github_repo" "$CONFIG_FILE")

    echo "Checking ${display_name} (GitHub: ${github_repo})..."

    local has_updates=false
    local resolve_count
    resolve_count=$(yq -r ".integrations.${integration_id}.resolve | length" "$CONFIG_FILE")

    # Step 1: Discover all Hibernate Validator bundles
    echo "  Discovering Hibernate Validator bundles..."
    local discovered_paths
    discovered_paths=$(discover_liberty_hv_bundles "$github_repo") || true

    if [[ -n "$discovered_paths" ]]; then
        while IFS= read -r discovered_path; do
            local is_configured=false
            for (( i=0; i<resolve_count; i++ )); do
                local config_path
                config_path=$(yq -r ".integrations.${integration_id}.resolve[$i].path" "$CONFIG_FILE")
                if [[ "$discovered_path" == "$config_path" ]]; then
                    is_configured=true
                    break
                fi
            done

            if [[ "$is_configured" != true ]]; then
                echo "    UNTRACKED: Found Hibernate Validator bundle at ${discovered_path}"
                echo "    Suggested: add to ${CONFIG_FILE#"${REPO_ROOT}/"}"
                has_updates=true
            fi
        done <<< "$discovered_paths"
    fi

    # Step 2: For each configured bundle, check HV version and constraint
    for (( i=0; i<resolve_count; i++ )); do
        local path project feature
        path=$(yq -r ".integrations.${integration_id}.resolve[$i].path" "$CONFIG_FILE")
        project=$(yq -r ".integrations.${integration_id}.resolve[$i].project" "$CONFIG_FILE")
        feature=$(yq -r ".integrations.${integration_id}.resolve[$i].feature" "$CONFIG_FILE")

        local file_content
        if ! file_content=$(gh api "repos/${github_repo}/contents/${path}" \
            -H "Accept: application/vnd.github.raw+json" 2>&1); then
            echo "  WARNING: Failed to fetch ${path}: ${file_content}" >&2
            continue
        fi

        local resolved_version
        resolved_version=$(echo "$file_content" \
            | grep -oP 'org\.hibernate\.validator:hibernate-validator;version=\K[^\s;,]+' \
            || true)

        if [[ -z "$resolved_version" ]]; then
            echo "  WARNING: Could not extract Hibernate Validator version from ${path}" >&2
            continue
        fi

        local hibernate_series
        hibernate_series=$(extract_series "$resolved_version" 2)
        echo "  ${feature}: hibernate-validator ${resolved_version} (series ${hibernate_series})"

        local series_file
        series_file=$(find_series_file "$project" "$resolved_version")

        if [[ -z "$series_file" ]]; then
            echo "    UNTRACKED: No series.yml found for ${project} ${hibernate_series}"
            has_updates=true
            continue
        fi

        local has_constraint
        has_constraint=$(yq ".integration_constraints.${integration_id} | select(. != null)" "$series_file" 2>/dev/null || true)

        if [[ -z "$has_constraint" ]]; then
            local rel_path="${series_file#"${REPO_ROOT}/"}"
            echo "    UNTRACKED: ${rel_path} has no ${integration_id} constraint"
            echo "    Suggested: add ${integration_id} integration_constraint for ${feature}"
            has_updates=true
        else
            echo "    Already tracked in ${series_file#"${REPO_ROOT}/"}"
        fi
    done

    # Step 3: Check if latest Liberty release is newer than max tracked version
    echo "  Checking for newer Liberty releases..."
    local releases_output
    if ! releases_output=$(gh api "repos/${github_repo}/releases" --jq \
        '[.[] | select(.prerelease == false and .draft == false)][0].tag_name' 2>&1); then
        echo "  WARNING: Could not determine latest Liberty release: ${releases_output}" >&2
    elif [[ -n "$releases_output" ]]; then
        local latest_version="${releases_output#gm-}"

        local max_tracked
        max_tracked=$(find_max_tracked_version "$integration_id")

        if [[ -n "$max_tracked" ]] && version_gt "$latest_version" "$max_tracked"; then
            echo "    STALE: Latest Liberty release ${latest_version} is newer than max tracked ${max_tracked}"
            echo "    Suggested: update 'to:' bounds in integration_constraints"
            has_updates=true
        else
            echo "    Up to date (latest release: ${latest_version}, max tracked: ${max_tracked})"
        fi
    else
        echo "  WARNING: Could not determine latest Liberty release" >&2
    fi

    if [[ "$has_updates" == true ]]; then
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    local updates_found=false
    local integration_ids
    integration_ids=$(yq -r '.integrations | keys | .[]' "$CONFIG_FILE")

    while IFS= read -r integration_id; do
        local integration_type
        integration_type=$(yq -r ".integrations.${integration_id}.type // \"maven\"" "$CONFIG_FILE")

        if [[ "$integration_type" == "github" ]]; then
            if ! check_liberty_integration "$integration_id"; then
                updates_found=true
            fi
            continue
        fi

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
        if ! latest=$(check_for_update "$group_id" "$artifact_id" "$check_version" \
                "$max_tracked" "$series_components"); then
            continue
        fi

        if [[ -z "$latest" ]]; then
            echo "  Up to date (series ${max_tracked} is the latest)"
            continue
        fi

        local latest_series
        latest_series=$(extract_series "$latest" "$series_components")
        echo "  New series available: ${latest_series} (latest release: ${latest})"
        updates_found=true

        # Resolve Hibernate dependencies
        echo "  Resolving Hibernate dependencies..."
        local resolved_lines
        if ! resolved_lines=$(resolve_hibernate_versions "$integration_id" "$group_id" "$artifact_id" "$latest"); then
            continue
        fi

        if [[ -n "$resolved_lines" ]]; then
            while IFS=' ' read -r project coord resolved_version; do
                local hibernate_series
                hibernate_series=$(extract_series "$resolved_version" 2)
                echo "    ${coord} -> ${resolved_version} (series ${hibernate_series})"

                local series_file
                series_file=$(find_series_file "$project" "$resolved_version")
                if [[ -n "$series_file" ]]; then
                    local rel_path="${series_file#"${REPO_ROOT}/"}"
                    echo "    Suggested update: ${rel_path} — extend ${integration_id} to: '${latest_series}'"
                fi
            done <<< "$resolved_lines"
        else
            echo "    Could not resolve Hibernate dependencies from this BOM."
        fi
    done <<< "$integration_ids"

    if [[ "$updates_found" == true ]]; then
        echo ""
        echo "FAILURE: One or more integrations have untracked series. See details above."
        exit 1
    fi

    echo ""
    echo "All integrations are up to date."
}

main "$@"
