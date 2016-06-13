= How to build hibernate.org
ifdef::env-github[:outfilesuffix: .adoc]
ifndef::env-github[:outfilesuffix: /]
:awestruct-layout: title-nocol
:toc:
:toc-placement: preamble

A bit of Git, a bit of Ruby and you will get your local hibernate.org served.

== Prerequisites

* Get http://git-scm.com[Git]
* Get https://www.ruby-lang.org/en/[Ruby] > 1.9

== Installation

=== Ensure Rake is installed

Make sure https://github.com/jimweirich/rake[Rake] is available. It is often installed per default.

[source]
----
> rake --version
----

If you get "_command not found_":

[source]
----
> gem install rake
----

=== Ensure Bundler is installed

Make sure http://bundler.io/[Bundler] (version >= 1.10) is available. It manages your Ruby gems
locally to the project and prevents version conflicts between different Ruby projects.
Quoting from the website:

____
Bundler provides a consistent environment for Ruby projects by tracking and installing the exact
gems and versions that are needed.
____

[source]
----
> bundle -v
----

If you get "_command not found_" or a version < 1.10:

[source]
----
> gem install bundler
----

[[get-the-source]]
=== Get the source

[source]
----
> git clone git@github.com:hibernate/hibernate.org.git
> cd hibernate.org
----

=== Setup awestruct

[source]
----
> rake setup
----

=== Serve the site

[source]
----
rake preview
----

Point your browser to http://localhost:4242

== Tips & Tricks

=== How to edit/publish content

Refer to this link:/survival-guide{outfilesuffix}[guide]

=== Which other tasks exist in the Rake build file?

[source]
----
> rake --tasks
----

This will list the available tasks with a short description

=== I am getting errors when trying to execute *awestruct* directly

You need to use `bundle exec <command>` to make sure you get all required Gems. Check the *Rakefile*
to see how the different awestruct calls are wrapped.

=== If you are getting error after an update

----
> rake clean[all]
> rake setup
> rake preview
----

=== If your changes are not visible...

Panic! Then completely regenerate the site via:

[source]
----
> rake clean preview
----

=== Fedora 23 setup

Make sure the user is in the sudo group and install required dependencies for
compilation of native extensions:

[source]
----
> sudo dnf -y install gcc-c++ make ruby-devel libxml2-devel libxslt-devel redhat-rpm-config
----

[NOTE]
====
This is required regardless how you proceed from here (provided Ruby version vs RVM)
====

==== Using Ruby version provided by the Fedora packages

[source]
----
> sudo dnf -y install ruby
> gem install rake bundler
----

Continue <<get-the-source,here>>

==== Using RVM

How to Integrating RVM with gnome-terminal: http://rvm.io/integration/gnome-terminal

How to install RVM (http://rvm.io/rvm/install)

Install the GPG key:

[source]
----
gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
----

Install a stable Ruby version:

[source]
----
curl -sSL https://get.rvm.io | bash -s stable --ruby
git clone in.relation.to
cd in.relation.to
echo "rvm ruby-2.2@global" > .rvmrc
----

Load the .rvmrc file:

[source]
----
cd ../in.relation.to
----

Say yes to .rvmrc execution.

Continue <<awestruct-setup, here>>

=== Bugger that,...

I cannot get the enviroment up and running. Use Docker! Read link:/docker/README{outfilesuffix}[how]!

== License

The content of this repository is released under the link:http://www.apache.org/licenses/LICENSE-2.0.txt[ASL 2.0].

By submitting a "pull request" or otherwise contributing to this repository, you
agree to license your contribution under the respective licenses mentioned above.

== Acknowledgements

This website uses https://github.com/jbossorg/bootstrap-community[JBoss Community Bootstrap].

