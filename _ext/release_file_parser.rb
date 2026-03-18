require 'fileutils'

module Awestruct
  module Extensions
    # Awestrcut extension which traverses the given directory to find release information,
    # making it available in a hash.
    #
    # The assumption is that the parent directory is named after the project,
    # and release files are YAML files in a direct subdirectory called 'releases'.
    #
    # The release information for a given release can then be accessed, starting from the
    # top level site hash via:
    # site['projects'].['<project-name>'].['releases'].['<release-version>'], eg site['projects'].['validator'].['releases'].['5.0.0.Final'].
    #
    # The release data itself is stored in the hash using at the moment the following keys:
    # version, version_family, date, announcement_url, summary and displayed
    class ReleaseFileParser
      @@logger = Logger.new(STDERR)
      @@logger.level = Logger::INFO

      def initialize(data_dir="_data")
        @data_dir = data_dir
      end

      def watch(watched_dirs)
        watched_dirs << @data_dir
      end

      def execute(site)
        # keep reference to site
        @site = site

        # register the parent hash for all releases with the site
        @projects_hash = site[:projects]

        # traverse the file system to find the release information
        @projects_hash.each do |project_id, project|
          if (project[:id] == nil)
            project[:id] = project_id
          end
          findReleaseFiles(project)
        end
      end

      def findReleaseFiles(project)
        subproject_of = project['subproject_of']
        # Copy releases from a different directory tree for projects that are "part of" another
        if subproject_of
          project_id = subproject_of['project_id']
          subproject_id = project[:id]
          since_series = Version.new(subproject_of['since_series'])
        else
          project_id = project[:id]
          subproject_id = nil
          since_series = nil
        end

        releases_dir = "#{@data_dir}/projects/#{project_id}/releases/"
        if !File.directory?(releases_dir)
          @@logger.info("#{project['name']} Skipping release processing as the release dir does not exist: #{releases_dir}")
          return
        end
        populateReleaseHashes( project, subproject_id, since_series, releases_dir )

        sortReleaseHashes( project )
      end

      def populateReleaseHashes(project, subproject_id, since_series, releases_dir)
        release_hash = project[:releases]
        if release_hash == nil
          release_hash = Hash.new
          project[:releases] = release_hash
        end
        release_series_hash = project[:release_series]
        if release_series_hash == nil
          release_series_hash = Hash.new
          project[:release_series] = release_series_hash
        end

        Dir.foreach(releases_dir) do |file_name|
          file = File.expand_path( file_name, releases_dir )
          # skip '.' and '..'
          if ( file_name.start_with?( "." ) )
            next
          else
            # This directory represents a release series
            series = createSeries( project, subproject_id, file )

            if since_series && Version.new(series.version) < since_series
              next
            end

            release_series_hash[series.version] = series

            # Populate this series' releases
            Dir.foreach(file) do |sub_file_name|
             sub_file = File.expand_path( sub_file_name, file )
              # skip '.' and '..' and 'series.yml'
              if ( File.directory?( sub_file ) || File.basename( sub_file ) == "series.yml" )
                next
              else
                release = createRelease( project, subproject_id, series, sub_file )
                series.releases.push( release )
                release_hash[release.version] = release
              end
            end
          end
        end
      end

      def createSeries(project, subproject_id, series_dir)
        series_file = File.expand_path( "./series.yml", series_dir )
        series = @site.engine.load_yaml( series_file )

        subproject_series = subproject_id == nil ? nil : series[:subprojects]&.[](subproject_id)
        if subproject_series
          series = series.merge(subproject_series)
        end

        series[:project] = project
        if ( series[:version] == nil )
          series[:version] = File.basename( series_dir )
        end

        if ( series[:license] == nil )
          series[:license] = project['license']
        end

        series[:releases] = Array.new
        return series
      end

      def createRelease(project, subproject_id, series, release_file)
        unless ( release_file =~ /.*\.yml$/ )
          abort( "The release file #{release_file} does not have the YAML (.yml) extension!" )
        end

        release = @site.engine.load_yaml( release_file )

        subproject_release = subproject_id == nil ? nil : release[:subprojects]&.[](subproject_id)
        if subproject_release
          release = release.merge(subproject_release)
        end

        release[:project] = project
        release[:series] = series
        if ( release[:version] == nil )
          File.basename( release_file ) =~ /^(.*)\.\w*$/
          release[:version] = $1
        end
        if ( series != nil )
          release[:version_family] = series.version
        end

        if release.version =~ /.*\.(Alpha[0-9]+|Beta[0-9]+|CR[0-9]+)$/
          release.stable = false
        elsif release.version =~ /.*\.(Final|SP[0-9]+)/
          release.stable = true
        else
          raise StandardError, "Unsupported version scheme for #{release_file}: #{release.version}"
        end

        if release[:scm_tag] == nil
          if project['github']['final_suffix_in_tags']
            release[:scm_tag] = release.version
          else
            release[:scm_tag] = release.version =~ /^(.*).Final$/ ? $1 : release.version
          end
        end

        if ( release[:license] == nil )
          release[:license] = series.license
        end
        
        return release
      end

      def hasActiveIntegration(series)
        series[:integration_constraints]&.each do |integration_key,integration_constraint|
          integration = @site.integrations[integration_key]
          next unless integration[:downstream] && integration[:hibernate_involvement]
          integration[:active_series]&.each do |active_version_string|
            return true if Version.new(active_version_string).matches?(integration_constraint[:version])
          end
        end
        false
      end

      def sortReleaseHashes(project)
        releases = project[:releases]
        unless releases == nil
          releases = Hash[releases.sort_by { |key, value| Version.new(key) }.reverse]
          project[:releases] = releases

          # Also add useful, but redundant information to the objects
          found_release = false
          found_stable_release = false
          releases.values.each do |release|
            release.latest = false
            release.latest_stable = false

            if !found_release
              found_release = true
              release.latest = true
              project[:latest_release] = release
            end
            if !found_stable_release && release.stable
              found_stable_release = true
              release.latest_stable = true
              project[:latest_stable_release] = release
            end
          end
        end
        series = project[:release_series]
        unless series == nil
          series = Hash[series.sort_by { |key, value| Version.new(key) }.reverse]
          project[:release_series] = series

          # Also add useful, but redundant information to the objects
          found_series = false
          found_stable_series = false
          series.each do |series_version, series|
            releases = series.releases
            releases = releases.sort_by { |release| Version.new(release.version) }.reverse
            series.releases = releases

            series.stable = releases.first.stable

            if !found_series
              found_series = true
              series.latest = true
              project[:latest_series] = series
            else
              series.latest = false
            end
            if !found_stable_series && series.stable
              found_stable_series = true
              series.latest_stable = true
              project[:latest_stable_series] = series
              if series[:status] == nil
                series[:status] = 'latest-stable'
              end
            else
              series.latest_stable = false
              if series[:status] == nil
                if !series.stable
                  series[:status] = 'development'
                  project[:next_dev_series] = series
                elsif hasActiveIntegration(series)
                  # Series with an active integration are considered in "limited support":
                  # some team members will continue updating them for the specific needs
                  # of that integration.
                  series[:status] = 'limited-support'
                else
                  # By default, stable series that are not the latest are considered end-of-life'd.
                  # This can be overridden in yaml.
                  series[:status] = 'end-of-life'
                end
              end
            end
            series[:endoflife] = series[:status] == 'end-of-life'

            # The latest series might have its own branch, or might still be on main.
            # We don't know so we won't try to guess.
            if series[:scm_branch] == nil && !series.latest
              series[:scm_branch] = series.version
            end
            series.latest_scm_ref = series[:scm_branch] || series.releases&.first&.scm_tag
          end
        end
        project[:active_release_series] = project[:release_series].nil? ? nil
            : project[:release_series].values.select{|s| !s[:displayed].nil? ? s.displayed : s[:status] != 'end-of-life'}
        project[:older_release_series] = project[:release_series].nil? ? nil
            : project[:release_series].values.select{|s| !s[:displayed].nil? ? !s.displayed : s[:status] == 'end-of-life'}
      end
    end

    # Custom version class able to understand and compare the project versions of Hibernate projects
    class Version
      include Comparable

      attr_reader :major, :minor, :micro, :suffix

      def initialize(version="")
        version_str = version.is_a?(Hash) ? (version[:value] || version['value']) : version
        v = version_str.to_s.split(".")
        @major = v[0].to_i
        @minor = v[1].to_i
        @micro = v[2].to_i
        @suffix = v[3] == nil ? nil : VersionSuffix.new(v[3])
      end

      def <=>(other)
        return @major <=> other.major if ((@major <=> other.major) != 0)
        return @minor <=> other.minor if ((@minor <=> other.minor) != 0)
        return @micro <=> other.micro if ((@micro <=> other.micro) != 0)
        return @suffix <=> other.suffix
      end

      def matches?(constraint)
        if constraint.is_a?(Array)
          constraint.each do |c|
            if self.matches?(c)
              return true
            end
          end
        elsif constraint.is_a?(Hash) && constraint.key?(:from)
          from_version = Version.new(constraint[:from])
          to_version = constraint[:to] ? Version.new(constraint[:to]) : nil
          return self >= from_version && (to_version.nil? || self <= to_version)
        else
          constraint_version = Version.new(constraint)
          # Constraint "7" matches "7.1", "7.2", etc.
          # Constraint "7.0" matches "7.0.1", "7.0.2", etc.
          return false if @major != constraint_version.major
          return true if constraint_version.minor == 0 && constraint_version.micro == 0

          return false if @minor != constraint_version.minor
          return true if constraint_version.micro == 0

          return @micro == constraint_version.micro
        end
        false
      end

      def self.sort
        self.sort!{|a,b| a <=> b}
      end

      def to_s
        @major.to_s + "." + @minor.to_s + "." + @micro.to_s + "." + @suffix.to_s
      end
    end

    class VersionSuffix
      include Comparable

      attr_reader :prefix, :number

      def initialize(bugfix="")
        split = bugfix.scan(/^([A-Za-z\-_]+)([0-9]+)?$/)
        @prefix = split.first[0]
        @number = split.first[1]&.to_i
      end

      def <=>(other)
        return @prefix <=> other.prefix if ((@prefix <=> other.prefix) != 0)
        return @number <=> other.number
      end

      def self.sort
        self.sort!{|a,b| a <=> b}
      end

      def to_s
        @bugfix + @number&.to_s
      end
    end
  end
end
