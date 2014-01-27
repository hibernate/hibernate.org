#! /bin/bash
# build site in prod profile
# clone hibernate.github.io in _tmp if not present
# copy site to git repo, commit and push
rake clean gen[production]
rc=$?
if [[ $rc != 0 ]] ; then
    echo "ERROR: Execution of Rake script failed."
    exit $rc
fi
cd _tmp
if [ ! -d "hibernate.github.io" ];
then
  git clone --depth 1 git@github.com:hibernate/hibernate.github.io.git
fi
cd hibernate.github.io
git fetch origin
git reset --hard origin/master
git rm -r .

# we filter cache as in production we shouldn't need that data
rsync -av \
      --filter "- /cache" \
      ../../_site/ .

git add .
if git commit -m "Publish generated site"; then git push origin master; fi

cd ../..
