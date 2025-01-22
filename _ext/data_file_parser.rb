require 'fileutils'
require 'json'

module Awestruct
  module Extensions
    # Parses _data/*.yml files and makes them available under site.* (as a hash) and site.data_json.* (as a JSON string)
    # Release info parsing is more complex and handled in release_file_parser.rb instead.
    class DataFileParser

      def initialize(data_dir="_data")
        @data_dir = data_dir
      end

      def watch(watched_dirs)
        watched_dirs << @data_dir
      end

      def execute(site)
        Dir[ "#{site.dir}/#{@data_dir}/*.yml" ].each do |file_name|
           data = site.engine.load_yaml( file_name )
           site.data_json ||= Hash.new
           site.data_json[File.basename(file_name, '.yml')] = data.to_json
        end
      end
    end
  end
end