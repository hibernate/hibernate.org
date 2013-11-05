module Awestruct
  module Extensions
    # Awestrcut extension which traverses the given directory to find release files, specifyig
    # the relevant release information for a given release and project. Directories are used to 
    # create sub-hashes.
    class ReleaseFileParser

      def initialize(data_dir="_data")
        @data_dir = data_dir
      end

      def watch(watched_dirs)
          watched_dirs << @data_dir
      end

      def execute(site)
        # first create the nested hashes for the release data
        createReleaseData( "#{site.dir}/#{@data_dir}", site, site )

        # also create a sorted array for the releases
        createSortedReleaseHash( site )
      end

      def createReleaseData(dir, hash, site)
        Dir[ "#{dir}/*" ].each do |entry|
          if ( File.directory?( entry ) )
            subHash = createSubHashForKey(hash, File.basename( entry ))
            createReleaseData( entry, subHash, site )
          else
            createHashForRelease( hash, entry, site )
          end
        end
      end

      # Creates a sub hash with the specified key in case it does not exist yet
      def createSubHashForKey(hash, key)
        if ( hash[key].nil? )
          hash[key] = Hash.new
        end
        hash[key]
      end

      # Creates a hash with the date read from a release file
      def createHashForRelease(hash, file, site)
          # load the page
          releaseHash = site.engine.load_page( file )
          # use a regexp to get the file name without extension into the pattern buffer
          File.basename( file ) =~ /^(.*)\.\w*$/
          # use the file (release) name as key
          key = $1.to_s
          hash[ key ] = releaseHash
      end

      def createSortedReleaseHash(site)
        site.projects.each do |projectname, project|
          releases = project[:releases]
          unless releases.nil?
            sortedReleases = Hash[releases.sort_by { |key, value| Version.new(key) }.reverse]
            site.projects[projectname][:sorted_releases] = sortedReleases.values
          end
        end
      end
    end

    # Custom version class able to understand and compate the project versions of Hibernate projects
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
