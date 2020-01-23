# This file is a rake build file. The purpose of this file is to simplify
# setting up and using Awestruct. It's not required to use Awestruct, though it
# does save you time (hopefully). If you don't want to use rake, just ignore or
# delete this file.
#
# If you're just getting started, execute this command to install Awestruct and
# the libraries on which it depends:
#
#  rake setup
#
# To run in Awestruct in editor mode, execute:
#
#  rake
#
# To clean the generated site before you build, execute:
#
#  rake clean preview
#
# To get a list of all tasks, execute:
#
#  rake -T
#
# Now you're Awestruct with rake!
require 'bundler'
task :default => :preview

#####################################################################################
# Bundler and environment related tasks
#####################################################################################
# Perform initialization steps, such as setting up the PATH
task :init do
  cmd = "bundle check"
  msg cmd
  system cmd or raise "Bundle dependencies not satisfied. Run 'rake setup' first", :warn
end

desc 'Setup the environment to run Awestruct using Bundler'
task :setup do |task, args|
  bundle_command = 'bundle install'
  msg "Executing '#{bundle_command}' in clean Bundler environment"
  Bundler.with_unbundled_env do
    system bundle_command
  end

  msg 'Bundle installed'
  # Don't execute any more tasks, need to reset env
  exit 0
end

desc 'Update gems ignoring the previously installed gems specified in Gemfile.lock'
task :update => :init do
  system 'bundle update'
  # Don't execute any more tasks, need to reset env
  exit 0
end

#####################################################################################
# Awestruct related tasks
#####################################################################################
desc 'Build and preview the site locally in development mode. preview[<options>] can be used to pass awestruct options, eg \'preview[--no-generate]\''
task :preview, [:profile, :options] => :init do |task, args|
  profile = get_profile args
  options = args[:options]
  # Must bind to 0.0.0.0 instead of the default "localhost" in order to allow port forwarding in Docker container
  run_awestruct "-P #{profile} --server --bind 0.0.0.0 --auto --no-livereload #{options}"
end

desc 'Generate the site using the specified profile, default is \'development\'. Additional options can also be specified, eg \'gen[development, \'-w\']'
task :gen, [:profile, :options] => :init do |task, args|
  profile = get_profile args
  options = args[:options]
  run_awestruct "-P #{profile} -g --force #{options}"
end

desc 'Clean out generated site and temporary files, using [all-keep-deps] removes caches as well, using [all] will also delete local gem files'
task :clean, :option do |task, args|
  require 'fileutils'
  dirs = ['.awestruct', '.sass-cache', '_site', '_tmp', '_site_tmp']
  if args[:option] == 'all'
    dirs << '.wget-cache'
  end
  dirs.each do |dir|
    FileUtils.remove_dir dir unless !File.directory? dir
  end
end

#####################################################################################
# Test
#####################################################################################
desc 'Run Rspec tests'
task :test do
  all_ok = system "bundle exec rspec _spec --format documentation"
  if all_ok == false
    fail "RSpec tests failed - aborting build"
  end
end

#####################################################################################
# Helper methods
#####################################################################################
# Execute Awestruct
def run_awestruct(args)
  cmd = "bundle exec awestruct #{args}"
  msg cmd
  system cmd or raise "ERROR: Running Awestruct failed."
end

def get_profile(args)
  if args[:profile].nil?
    profile = "development"
  else
    profile = args[:profile]
  end
end

# Print a message to STDOUT
def msg(text, level = :info)
  case level
  when :warn
    puts "\e[31m#{text}\e[0m"
  else
    puts "\e[33m#{text}\e[0m"
  end
end

