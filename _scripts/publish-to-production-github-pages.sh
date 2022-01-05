#!/bin/bash -e

GENERATED_SITE_DIRECTORY=$(readlink -e "_site/")

# Clone git repo for hibernate.github.io
HIBERNATE_GITHUB_IO_CLONE=$(mktemp -d --tmpdir 'hibernate-github-io-XXXXXXXXXX')
# Make sure to clean up when the script exits
trap "rm -rf '${HIBERNATE_GITHUB_IO_CLONE}'" EXIT
pushd "${HIBERNATE_GITHUB_IO_CLONE}"
git clone --depth 1 git@github.com:hibernate/hibernate.github.io.git .

# Set up commit info
git config user.name "Hibernate CI"
git config user.email "ci@hibernate.org"

# copy site to git repo, commit and push.
# we filter .git to preserve the git metadata
# we filter cache as in production we shouldn't need that data
rsync -av \
      --delete \
      --filter "- .git" \
      --filter "- /cache" \
      "${GENERATED_SITE_DIRECTORY}/" .

if git add -A . && git commit -m "Publish generated site"
then
 git push origin HEAD:main
fi

popd
