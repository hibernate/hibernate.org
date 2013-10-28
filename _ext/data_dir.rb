module Awestruct
  module Extensions
    class DataDir

      def initialize(data_dir="_data")
        @data_dir = data_dir
      end

      def watch(watched_dirs)
          watched_dirs << @data_dir
      end

      def execute(site)
        executeSubDir( "#{site.dir}/#{@data_dir}", site, site )
      end

      def executeSubDir(dir, property, site)
        Dir[ "#{dir}/*" ].each do |entry|
          if ( File.directory?( entry ) )
            data_key = File.basename( entry )
            data_map = property.send( "#{data_key}" )
            data_map = data_map.nil? ? {} : data_map
            executeSubDir( entry, data_map, site )
            property.send( "#{data_key}=", data_map )
          else
            # the regexp removed the extension to a file
            File.basename( entry ) =~ /^(.*)\.\w*$/
            key = $1.to_sym
            chunk_page = site.engine.load_page( entry )
            property[ key ] = chunk_page
          end
        end
      end
    end


    # Order releases by most recent first and convert them to an Array of them instead of Hash
    class ReleaseSorter
      def execute(site)
        site.projects.each do |projectname, project|
          releases = project[:releases]
          if releases.is_a? Hash
            releases.sort_by { |key, value| Version.new(key) }
            site.projects[projectname][:releases] = releases.values.reverse
          end
        end
      end
    end

    class Version
      include Comparable

      attr_reader :major, :feature_group, :feature, :bugfix

      def initialize(version="")
        v = version.to_s.split(".")
        @major = v[0].to_i
        @feature_group = v[1].to_i
        @feature = v[2].to_i
        @bugfix = v[3].to_s
      end
      
      def <=>(other)
        return @major <=> other.major if ((@major <=> other.major) != 0)
        return @feature_group <=> other.feature_group if ((@feature_group <=> other.feature_group) != 0)
        return @feature <=> other.feature if ((@feature <=> other.feature) != 0)
        return @bugfix <=> other.bugfix
      end

      def self.sort
        self.sort!{|a,b| a <=> b}
      end

      def to_s
        @major.to_s + "." + @feature_group.to_s + "." + @feature.to_s + "." + @bugfix.to_s
      end
    end
  end
end
