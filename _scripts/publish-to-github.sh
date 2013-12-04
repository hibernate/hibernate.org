#! /bin/bash
# build site in prod profile
# clone hibernate.github.io in _tmp if not present
# copy site to git repo, commit and push
rake clean gen[production]
cd _tmp
if [ ! -d "hibernate.github.io" ];
then
  git clone --single-branch --branch master git@github.com:hibernate/hibernate.github.io.git
fi
cd hibernate.github.io
git fetch origin
git reset --hard origin/master
git rm -r .

rsync -av \
      ../../_site/ .

git add .
git commit -m "Publish generated site"
git push origin master
cd ../..
