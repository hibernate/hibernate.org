#!/bin/bash -e
# This script should be invoked from the root of the repo,
# after the website has been generated.

# Publish
rsync --delete -avh --filter "- /cache" _site/ in.relation.to:/var/www/hibernate.org/
