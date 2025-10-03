require 'fileutils'
require 'json'

module Awestruct
  module Extensions
    class MetadataPublisher
      @@logger = Logger.new(STDERR)
      @@logger.level = Logger::INFO

      def execute(site)
        metadata_hash_for_json = Hash.new
        site.data_json ||= Hash.new
        site.data_json[:metadata] = metadata_hash_for_json

        site[:projects].each do |project_id, project|
          if (project[:id] == nil)
            project[:id] = project_id
          end
          metadata_hash_for_json[project_id] = filterForJson(project).to_json
        end
      end

      def filterForJson(project)
        filtered = filter(project, {
            description: nil,
            copyright: nil,
            jira: nil
        })
        filtered[:series] = project[:release_series]&.transform_values {|v| filter(v, {
            # Just make to mention in this object all properties you want to keep in JSON.
            # That's what we'll keep.
            summary: nil,
            status: nil,
            license: {
                name: nil,
                since: nil
            },
            links: nil
          })
        }
        return filtered
      end

      def filter(object, prototype)
        if object == nil
          return nil
        elsif prototype.kind_of?(Array)
          return object.collect {|o| filter(o, prototype[0])}
        elsif prototype.kind_of?(Hash)
          filtered = Hash.new
          prototype.each_key { |key|
            filtered[key] = filter(object[key], prototype[key])
          }
          return filtered
        else
          return object
        end
      end
    end
  end
end
