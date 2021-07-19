#!/bin/bash
# This script should be invoked from the root of the repo,
# after the website has been generated.

# Publish
rsync --delete -avh _site/ in.relation.to:/var/www/staging-hibernate.org/
rc=$?
if [[ $rc != 0 ]] ; then
    echo "ERROR: Site sync failed!"
    exit $rc
fi

