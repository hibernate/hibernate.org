#!/bin/bash -e
# This script should be invoked from the root of the repo,
# after the website has been generated,
# with a clone of https://github.com/hibernate/hibernate.github.io.git
# available in directory _publish_tmp/hibernate.github.io

pushd _publish_tmp/hibernate.github.io

# copy site to git repo, commit and push.
# we filter .git to preserve the git metadata
# we filter cache as in production we shouldn't need that data
rsync -av \
      --delete \
      --filter "- .git" \
      --filter "- /cache" \
      ../../_site/ .

if git add -A . && git commit -m "Publish generated site"
then
 git push origin HEAD:main
fi

popd
