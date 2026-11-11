source 'https://rubygems.org'

gem 'bundler', '4.0.24'

# Main site dependencies
gem 'awestruct', '0.6.7'
gem 'base64'          # Required by em-websocket, but no longer a Ruby default gem
gem 'ostruct'         # Required by Awestruct, but no longer a Ruby default gem
gem 'syslog'          # Loaded by logging, but no longer a Ruby default gem
gem 'sass'
gem 'json'
gem 'haml', '< 6.0'    # Haml 6 would require udpating our filter registration code
gem 'logging'

gem 'uglifier'         # Ruby wrapper for UglifyJS JavaScript compressor
gem 'cssminify'        # CSS compression using YUI compressor
gem 'htmlcompressor'   # Adds in HTML minification, helps remove the warning on awestruct startup
gem 'redcarpet'        # Markdown processing
gem 'asciidoctor'      # Asciidoc renderer

## Non Windows
gem 'mini_racer', :platforms => :ruby

## Windows
gem 'win32-open3-19', :platforms => :windows

# Test dependencies
gem 'rspec'

# For previews
gem 'webrick'

# To enable guard and livereload
gem 'guard'
gem 'guard-livereload'
gem 'yajl-ruby'

# Debugger
gem 'pry-byebug'

