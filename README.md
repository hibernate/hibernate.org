---
layout: project
title: readme
---
# Readme - How to build <http://hibernate.org>

A bit of Git, a bit a Ruby and you will get your local version of hibernate.org served.

## Installation

* get Git
* get Ruby 1.9.3 (part of the RVM install if you follow that path - see below)
* get RubyGems 1.3.6 or above
* get GNU Wget 1.14
* if on Mac OS, get XCode (needed for native gems)

Install Git to your system. [GitHub's help page](http://help.github.com/) is a good starting
point. [Emmanuel's blog](http://in.relation.to/Bloggers/HibernateMovesToGitGitTipsAndTricks)
on Git tips and tricks is useful too.

Ruby like many other platforms has its dependency hell. We do recommend you use RVM to
isolate your dependencies. The RVM steps are optional though.

Install [RVM](https://rvm.io).

Then set up the isolated environment

    rvm install 1.9.3
    rvm use 1.9.3
    rvm gemset create awestruct

Next, let's retrieve the website.

<!-- lang: bash -->
    git clone git@github.com:hibernate/hibernate.org.git
    cd hibernate.org

If you use RVM, add a `.rvmrc` file in the directory containing

    rvm ruby-1.9.3@awestruct

This will set up the right environment when you enter the directory.
The first time, leave and reenter the directory `cd ..;cd hibernate.org`.

Finally, let's install Awestruct

<!-- lang: bash -->
    gem install bundler
    # or sudo gem install bundler on Mac OS X if you don't use RVM
    bundle install

Note that if someone updates Awestruct or any dependent gem via the `Gemfile` dependency
management, you need to rerun `bundle install`.

### Getting the Hibernate specific resources

As a temporary measure, resources from the JBoss Community Bootstrap are compiled
externally. Retrieve this [zip file](https://dl.dropboxusercontent.com/u/692318/redhat/hibernate-site/static.hibernate.org.zip),
and unzip it under `hibernate.org/cache`. You should get a `hibernate.org/cache/static.hibernate.org/...`.

Make sure to get this zip file regularly if you see UI discrepencies.

## Serve the site locally

* Run  `rake preview`
* Open your browser to <http://localhost:4242>

Any change will be automatically picked up except for `_partials` files.

Note that you might see warnings at startup like

    WARNING: Missing required dependency to activate optional built-in extension coffeescripttransform.rb
      cannot load such file -- coffee-script
    Using profile: development
    Generating site: http://localhost:4242
    Skipping files cache update.
    CodeRay::Scanners could not load plugin :bash; falling back to :text
    CodeRay::Scanners could not load plugin :bash; falling back to :text
    CodeRay::Scanners could not load plugin :bash; falling back to :text
    CodeRay::Scanners could not load plugin :bash; falling back to :text
    CodeRay::Scanners could not load plugin :bash; falling back to :text
    CodeRay::Scanners could not load plugin :bash; falling back to :text
    [Listen warning]:
    The blocking parameter of Listen::Listener#start is deprecated.
    Please use Listen::Adapter#start for a non-blocking listener and Listen::Listener#start! for a blocking one.

That's ok, it's not your fault ;) It's related to some Awestruct limitations.

### If your changes are not visible...

If for whatever reason you make some changes which don't show up, you can
completely regenerate the site:

<!-- lang: bash -->
    rake clean preview

### If serving the site is slow...

On Linux, serving the file may be atrociously slow 
(something to do with WEBRick).

Use the following alternative:

* Go in your `~/hibernate.org` directory.  
* Run  `awestruct --auto -P development`
* In parallel, go to the `~/hibernate.org/_site` directory
* Run `python -m SimpleHTTPServer 4242`

You should be back to millisecond serving :)

## License

The content of this repository is released under 
TBD.
Sample code available on this website is released under TBD.

By submitting a "pull request" or otherwise contributing to this repository, you
agree to license your contribution under the respective licenses mentioned above.

### Acknowledgements

This website uses [JBoss Community Bootstrap](https://github.com/jbossorg/bootstrap-community).

## Next steps

You can have a look at our [survival guide to editing this website](/survival-guide/) to get you started.
