#!/bin/bash

# Clone hibernate.github.io in _publish_tmp if not present.
# Using _tmp would mean more headaches related to access rights from the container,
# which usually removes that dir in "rake clean": let's avoid that.
mkdir _publish_tmp 2>/dev/null
cd _publish_tmp
if [ ! -d "hibernate.github.io" ];
then
  git clone --depth 1 git@github.com:hibernate/hibernate.github.io.git
fi

# Make sure the local clone is in sync with its remote
pushd hibernate.github.io
git fetch origin
git reset --hard origin/master

# copy site to git repo, commit and push.
# we filter cache as in production we shouldn't need that data
rsync -av \
      --delete \
      --filter "- /cache" \
      ../../_site/ .
rc=$?
if [[ $rc != 0 ]] ; then
    echo "ERROR: Site sync failed!"
    exit $rc
fi

git add -A .
if git commit -m "Publish generated site";
then
 git push origin master;
 rc=$?
fi
popd
popd
if [[ $rc != 0 ]] ; then
  echo "ERROR: Cannot push on site repository!"
  exit $rc
fi

