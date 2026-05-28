#!/usr/bin/env python3
"""
Extract Maven Central artifact links from built website and verify they exist.
"""
import os
import re
import sys
import time
from pathlib import Path
from urllib.parse import urlparse, parse_qs, unquote
from html.parser import HTMLParser
import urllib.request
import urllib.error

class MavenLinkExtractor(HTMLParser):
    """Extract Maven Central and Maven Repository links from HTML."""

    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            for attr, value in attrs:
                if attr == 'href' and value:
                    # Match Maven Central artifact links
                    if 'central.sonatype.com/artifact/' in value:
                        self.links.append(('central', value))
                    # Match direct Maven repo links
                    elif 'repo.maven.apache.org/maven2/' in value or 'repo1.maven.org/maven2/' in value:
                        self.links.append(('repo', value))

def extract_artifact_info_from_central_url(url):
    """Extract group_id, artifact_id, version from central.sonatype.com URL."""
    # Example: https://central.sonatype.com/artifact/org.hibernate/hibernate/1.2.5
    match = re.search(r'/artifact/([^/]+)/([^/]+)/([^/?]+)', url)
    if match:
        return {
            'group_id': match.group(1),
            'artifact_id': match.group(2),
            'version': match.group(3),
            'url': url
        }
    return None

def extract_artifact_info_from_repo_url(url):
    """Extract artifact info from repo.maven.apache.org URL."""
    # Example: https://repo.maven.apache.org/maven2/org/hibernate/hibernate/1.2.5/
    # or https://repo1.maven.org/maven2/org/hibernate/hibernate/1.2.5/hibernate-1.2.5.pom
    parsed = urlparse(url)
    path = parsed.path

    # Remove /maven2/ prefix
    path = re.sub(r'.*/maven2/', '', path)

    # Split into parts
    parts = [p for p in path.split('/') if p]

    if len(parts) >= 3:
        # Last part might be filename or empty
        version = parts[-1] if not parts[-1].endswith('.pom') and not parts[-1].endswith('.jar') else parts[-2]
        artifact_id = parts[-2] if not parts[-1].endswith('.pom') and not parts[-1].endswith('.jar') else parts[-3]

        # Group ID is everything before artifact_id
        if not parts[-1].endswith('.pom') and not parts[-1].endswith('.jar'):
            group_parts = parts[:-2]
        else:
            group_parts = parts[:-3]

        if group_parts:
            group_id = '.'.join(group_parts)
            return {
                'group_id': group_id,
                'artifact_id': artifact_id,
                'version': version,
                'url': url
            }

    return None

def check_artifact_exists_on_central(group_id, artifact_id, version):
    """Check if artifact exists on Maven Central via central.sonatype.com API."""
    # Use the central.sonatype.com artifact page
    url = f"https://central.sonatype.com/artifact/{group_id}/{artifact_id}/{version}"

    try:
        req = urllib.request.Request(url, method='HEAD')
        req.add_header('User-Agent', 'Mozilla/5.0 (compatible; Maven Artifact Checker/1.0)')
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.status == 200
    except urllib.error.HTTPError as e:
        return False
    except Exception as e:
        print(f"  Warning: Error checking {url}: {e}", file=sys.stderr)
        return None  # Unknown

def check_artifact_exists_on_repo(group_id, artifact_id, version):
    """Check if artifact exists on Maven repository by checking for POM file."""
    # Convert group_id to path
    group_path = group_id.replace('.', '/')

    # Try repo1.maven.org first (Maven Central's primary CDN)
    pom_url = f"https://repo1.maven.org/maven2/{group_path}/{artifact_id}/{version}/{artifact_id}-{version}.pom"

    try:
        req = urllib.request.Request(pom_url, method='HEAD')
        req.add_header('User-Agent', 'Mozilla/5.0 (compatible; Maven Artifact Checker/1.0)')
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.status == 200
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        return None  # Other error - unknown
    except Exception as e:
        print(f"  Warning: Error checking {pom_url}: {e}", file=sys.stderr)
        return None  # Unknown

def scan_html_files(site_dir):
    """Scan all HTML files in site directory and extract Maven links."""
    site_path = Path(site_dir)
    all_artifacts = {}

    if not site_path.exists():
        print(f"Error: Directory {site_dir} does not exist", file=sys.stderr)
        print("Have you built the site? Run the build command first.", file=sys.stderr)
        return {}

    html_files = list(site_path.rglob('*.html'))
    print(f"Scanning {len(html_files)} HTML files...\n")

    for html_file in html_files:
        try:
            with open(html_file, 'r', encoding='utf-8') as f:
                content = f.read()

            parser = MavenLinkExtractor()
            parser.feed(content)

            for link_type, url in parser.links:
                artifact_info = None

                if link_type == 'central':
                    artifact_info = extract_artifact_info_from_central_url(url)
                elif link_type == 'repo':
                    artifact_info = extract_artifact_info_from_repo_url(url)

                if artifact_info:
                    key = (artifact_info['group_id'], artifact_info['artifact_id'], artifact_info['version'])
                    if key not in all_artifacts:
                        all_artifacts[key] = {
                            'info': artifact_info,
                            'files': set()
                        }
                    all_artifacts[key]['files'].add(str(html_file.relative_to(site_path)))

        except Exception as e:
            print(f"Warning: Error processing {html_file}: {e}", file=sys.stderr)

    return all_artifacts

def extract_major_minor(version):
    """Extract major.minor version from a version string."""
    # Match patterns like: 1.2.3, 1.2.3.Final, 1.2beta1, etc.
    match = re.match(r'^(\d+)\.(\d+)', version)
    if match:
        return f"{match.group(1)}.{match.group(2)}"
    return "unknown"

def main():
    site_dir = '_site'

    if len(sys.argv) > 1:
        site_dir = sys.argv[1]

    print(f"Maven Central Artifact Checker")
    print(f"=" * 80)
    print(f"Site directory: {site_dir}\n")

    # Extract all artifacts
    artifacts = scan_html_files(site_dir)

    if not artifacts:
        print("No Maven Central artifact links found.")
        return 0

    print(f"Found {len(artifacts)} unique artifacts referenced in the site.\n")
    print("Checking which artifacts exist on Maven Central...")
    print("(This may take a while...)\n")

    missing_artifacts = []
    unknown_artifacts = []
    found_artifacts = []
    checked = 0

    for key, data in sorted(artifacts.items()):
        group_id, artifact_id, version = key
        info = data['info']

        # Check if artifact exists
        exists = check_artifact_exists_on_repo(group_id, artifact_id, version)

        checked += 1
        if checked % 10 == 0:
            print(f"  Checked {checked}/{len(artifacts)} artifacts...", end='\r')

        if exists is False:
            missing_artifacts.append((key, data))
        elif exists is None:
            unknown_artifacts.append((key, data))
        else:
            found_artifacts.append((key, data))

        # Be nice to Maven Central - rate limit
        time.sleep(0.2)

    print(f"  Checked {checked}/{len(artifacts)} artifacts... Done!      \n")

    # Organize data by artifact
    artifacts_data = {}

    # Collect all versions (found and missing) for each artifact
    for key, data in found_artifacts + missing_artifacts:
        group_id, artifact_id, version = key
        artifact_key = f"{group_id}:{artifact_id}"

        if artifact_key not in artifacts_data:
            artifacts_data[artifact_key] = {
                'versions_by_series': {},  # major.minor -> {'found': count, 'total': count}
                'missing_versions': []
            }

        major_minor = extract_major_minor(version)

        if major_minor not in artifacts_data[artifact_key]['versions_by_series']:
            artifacts_data[artifact_key]['versions_by_series'][major_minor] = {
                'found': 0,
                'total': 0
            }

        artifacts_data[artifact_key]['versions_by_series'][major_minor]['total'] += 1

        # Check if this version was found
        if (key, data) in found_artifacts:
            artifacts_data[artifact_key]['versions_by_series'][major_minor]['found'] += 1
        else:
            artifacts_data[artifact_key]['missing_versions'].append(version)

    # Report results
    print("=" * 80)
    print("ARTIFACTS REPORT")
    print("=" * 80)
    print()

    for artifact_key in sorted(artifacts_data.keys()):
        data = artifacts_data[artifact_key]

        # Determine status
        has_missing = len(data['missing_versions']) > 0
        status = "❌" if has_missing else "✅"

        print(f"{status} {artifact_key}")

        # Print versions found line
        version_parts = []
        for series in sorted(data['versions_by_series'].keys()):
            stats = data['versions_by_series'][series]
            version_parts.append(f"{series} ({stats['found']}/{stats['total']})")

        print(f"  Versions: {', '.join(version_parts)}")

        # Print missing versions line
        if data['missing_versions']:
            missing_str = ', '.join(sorted(data['missing_versions']))
            print(f"  Missing: {missing_str}")
        else:
            print(f"  Missing: (none)")

        print()

    # Detailed missing artifacts listing with file references
    if missing_artifacts:
        print("=" * 80)
        print(f"DETAILED MISSING ARTIFACTS ({len(missing_artifacts)}):")
        print("=" * 80)
        for key, data in missing_artifacts:
            group_id, artifact_id, version = key
            print(f"\n❌ {group_id}:{artifact_id}:{version}")
            print(f"   URL: {data['info']['url']}")
            print(f"   Referenced in:")
            for file_path in sorted(data['files']):
                print(f"     - {file_path}")
        print()

    if unknown_artifacts:
        print(f"UNKNOWN STATUS ({len(unknown_artifacts)}):")
        print("-" * 80)
        print("(Network errors or other issues prevented verification)")
        for key, data in unknown_artifacts:
            group_id, artifact_id, version = key
            print(f"\n⚠️  {group_id}:{artifact_id}:{version}")
            print(f"   URL: {data['info']['url']}")
        print()

    # Summary
    print("=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"Total artifacts checked: {len(artifacts)}")
    print(f"Existing artifacts: {len(found_artifacts)}")
    print(f"Missing artifacts: {len(missing_artifacts)}")
    print(f"Unknown status: {len(unknown_artifacts)}")
    print()

    # Return exit code based on results
    return 1 if missing_artifacts else 0

if __name__ == '__main__':
    sys.exit(main())
