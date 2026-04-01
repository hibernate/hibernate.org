require 'fileutils'
require_relative 'version'

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

        # After parsing all projects, compute integration compatibility tables
        computeIntegrationCompatibility()
      end

      def findReleaseFiles(project)
        subproject_of = project['subproject_of']
        # Copy releases from a different directory tree for projects that are "part of" another
        if subproject_of
          project_id = subproject_of['project_id']
          subproject_id = project[:id]
          project[:superproject_id] = project_id
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

        if subproject_id
          # Automatically add the constraint "this subproject is compatible with the same version of the superproject"
          superproject_constraint = Hash.new
          superproject_constraint[:version] = series[:version]
          series[:integration_constraints][project[:superproject_id]] = superproject_constraint
        end

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

      def markIntegrationStatuses(series)
        has_active = false
        series[:integration_constraints]&.each do |integration_key,integration_constraint|
          integration = @site.integrations[integration_key]
          integration_constraint[:active] = false
          next unless integration[:downstream] && integration[:hibernate_involvement]
          integration[:active_series]&.each do |active_version_string|
            if Version.new(active_version_string).matches?(integration_constraint[:version])
              integration_constraint[:status] = 'active'
              has_active = true
              break
            end
          end
          unless integration_constraint[:status]
            integration[:els_series]&.each do |active_version_string|
              if Version.new(active_version_string).matches?(integration_constraint[:version])
                integration_constraint[:status] = 'els'
                break
              end
            end
          end
        end
        has_active
      end

      def hasActiveIntegration(series)
        series[:integration_constraints]&.each do |integration_key,integration_constraint|
          return true if integration_constraint[:status] == 'active'
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

            # Mark which integrations are active before determining status
            markIntegrationStatuses(series)

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

      # Compute integration compatibility tables for all downstream integrations
      # This creates a reverse mapping: for each integration version, which project versions are compatible
      def computeIntegrationCompatibility()
        return if @site.integrations.nil?

        @site.integrations.each do |integration_id, integration|
          # Collect all constraint versions from all projects for this integration
          constraint_versions = []
          @projects_hash.each do |project_id, project|
            next if project[:release_series].nil?

            project[:release_series].each do |series_version, series|
              next if series[:integration_constraints].nil?
              constraint = series[:integration_constraints][integration_id]
              next if constraint.nil? || constraint[:version].nil?

              constraint_versions << constraint[:version]
            end
          end

          # Expand all integration versions
          integration_versions = Version.expand_from_constraints(constraint_versions, integration_id, integration)

          # For each integration version, find compatible project versions
          project_compatibility = Hash.new

          integration_versions.each do |integration_version|
            version_compatibility = Hash.new

            @projects_hash.each do |project_id, project|
              next if project[:release_series].nil?

              matches = []
              project[:release_series].each do |series_version, series|
                next if series[:integration_constraints].nil?
                constraint = series[:integration_constraints][integration_id]
                next if constraint.nil? || constraint[:version].nil?

                if Version.new(integration_version).matches?(constraint[:version])
                  comment = extractCommentFromConstraint(constraint[:version], integration_version)
                  matches << { :version => series_version, :comment => comment, :status => constraint[:status] }
                end
              end

              # Sort matches from lowest to highest version
              matches.sort_by! { |m| Version.new(m[:version]) }

              # Pack consecutive versions with the same status into ranges
              version_compatibility[project_id] = packProjectVersionsIntoRanges(matches)
            end

            project_compatibility[integration_version] = version_compatibility
          end

          integration[:project_compatibility] = project_compatibility
          integration[:versions] = integration_versions

          # Pack consecutive versions with identical compatibility into ranges
          integration[:version_ranges] = packVersionsIntoRanges(integration_versions, project_compatibility, integration, @projects_hash)

          # Mark if there are any older series
          integration[:has_older_series] = integration[:version_ranges].any? { |vr| !vr[:displayed] }
        end
      end

      # Pack consecutive integration versions with identical project compatibility into ranges
      # Returns an array of hashes with :display (string) and :compatibility (hash)
      def packVersionsIntoRanges(integration_versions, project_compatibility, integration, projects_hash)
        return [] if integration_versions.empty?

        ranges = []
        current_range_start = integration_versions.first
        current_range_versions = [current_range_start]
        current_compatibility = project_compatibility[current_range_start]
        current_displayed = computeVersionDisplayed(current_range_start, current_compatibility, integration, projects_hash)

        integration_versions[1..-1].each do |version|
          version_compatibility = project_compatibility[version]
          version_displayed = computeVersionDisplayed(version, version_compatibility, integration, projects_hash)

          # Check if this version has identical compatibility and displayed status to the current range
          if compatibilitiesEqual?(current_compatibility, version_compatibility) && current_displayed == version_displayed
            current_range_versions << version
          else
            # Different compatibility or displayed status - close current range and start new one
            ranges << createVersionRange(current_range_start, current_range_versions.last, current_compatibility, current_displayed)
            current_range_start = version
            current_range_versions = [version]
            current_compatibility = version_compatibility
            current_displayed = version_displayed
          end
        end

        # Close the last range
        ranges << createVersionRange(current_range_start, current_range_versions.last, current_compatibility, current_displayed)

        ranges
      end

      # Pack consecutive project versions with the same status into ranges
      # Returns an array of hashes with :version (string or hash with :from/:to), :comment, :status
      def packProjectVersionsIntoRanges(matches)
        return [] if matches.empty?

        packed = []
        current_range_start = matches.first
        current_range_versions = [current_range_start]
        current_status = current_range_start[:status]
        current_comment = current_range_start[:comment]

        matches[1..-1].each do |match|
          # Check if this version can be merged with the current range
          # Conditions: same status, same comment, and consecutive versions
          if match[:status] == current_status &&
             match[:comment] == current_comment &&
             areConsecutiveVersions?(current_range_versions.last[:version], match[:version])
            current_range_versions << match
          else
            # Different status/comment or not consecutive - close current range and start new one
            packed << createProjectVersionRange(current_range_start[:version], current_range_versions.last[:version], current_comment, current_status)
            current_range_start = match
            current_range_versions = [match]
            current_status = match[:status]
            current_comment = match[:comment]
          end
        end

        # Close the last range
        packed << createProjectVersionRange(current_range_start[:version], current_range_versions.last[:version], current_comment, current_status)

        packed
      end

      # Check if two versions are consecutive (e.g., 6.4 and 6.5, or 6.5.0 and 6.5.1)
      def areConsecutiveVersions?(version1_str, version2_str)
        v1 = Version.new(version1_str)
        v2 = Version.new(version2_str)

        # Same major version
        return false if v1.major != v2.major

        # Check if minor versions are consecutive
        if v1.minor + 1 == v2.minor && v1.micro == 0 && v2.micro == 0
          return true
        end

        # Check if micro versions are consecutive (same major and minor)
        if v1.minor == v2.minor && v1.micro + 1 == v2.micro
          return true
        end

        false
      end

      # Create a project version range object
      def createProjectVersionRange(from_version, to_version, comment, status)
        version = if from_version == to_version
                    from_version
                  else
                    { :from => from_version, :to => to_version }
                  end

        result = { :version => version, :status => status }
        result[:comment] = comment if comment
        result
      end

      # Check if two compatibility hashes are equal
      def compatibilitiesEqual?(compat1, compat2)
        return false if compat1.keys.sort != compat2.keys.sort

        compat1.each do |project_id, matches1|
          matches2 = compat2[project_id]
          return false if matches1.length != matches2.length

          # Compare each match (version and comment, but not status)
          matches1.each_with_index do |match1, i|
            match2 = matches2[i]
            # Compare version (can be string or hash with :from/:to)
            return false if !versionsEqual?(match1[:version], match2[:version])
            return false if match1[:comment] != match2[:comment]
          end
        end

        true
      end

      # Check if two version values are equal (handles both string and range formats)
      def versionsEqual?(v1, v2)
        if v1.is_a?(Hash) && v2.is_a?(Hash)
          v1[:from] == v2[:from] && v1[:to] == v2[:to]
        else
          v1 == v2
        end
      end

      # Create a version range object
      def createVersionRange(from_version, to_version, compatibility, displayed)
        version = if from_version == to_version
                    from_version
                  else
                    # Ensure range is displayed as smaller → larger
                    v1 = Version.new(from_version)
                    v2 = Version.new(to_version)
                    if v1 < v2
                      { :from => from_version, :to => to_version }
                    else
                      { :from => to_version, :to => from_version }
                    end
                  end

        { :version => version, :compatibility => compatibility, :displayed => displayed }
      end

      # Compute whether a version should be displayed based on integration settings and compatibility
      def computeVersionDisplayed(integration_version, compatibility, integration, projects_hash)
        has_active_or_els = integration[:active_series]&.any? || integration[:els_series]&.any?

        if has_active_or_els
          # If there are active or els series, check if this integration version is in those lists
          return true if integration[:active_series]&.include?(integration_version)
          return true if integration[:els_series]&.include?(integration_version)
          false
        else
          # If there are no active or els series, check if compatible with at least one displayed project series
          isCompatibleWithDisplayedSeries(compatibility, projects_hash)
        end
      end

      # Check if a version is compatible with at least one displayed project series
      def isCompatibleWithDisplayedSeries(compatibility, projects_hash)
        compatibility&.each do |project_id, matches|
          project = projects_hash[project_id]
          next if project.nil? || project[:release_series].nil?

          matches.each do |match|
            # Handle both packed (range) and unpacked (string) versions
            version_value = match[:version]
            series_versions = if version_value.is_a?(Hash) && version_value.key?(:from)
                                # For ranges, check both from and to versions
                                [version_value[:from], version_value[:to]]
                              else
                                [version_value]
                              end

            series_versions.each do |series_version|
              series = project[:release_series][series_version]
              next if series.nil?

              # A series is displayed if: displayed is nil/true, or status is not 'end-of-life'
              is_displayed = series[:displayed].nil? ? series[:status] != 'end-of-life' : series[:displayed]
              return true if is_displayed
            end
          end
        end

        false
      end

      # Extract comment from a constraint for a specific version
      def extractCommentFromConstraint(constraint_version, target_version)
        if constraint_version.is_a?(Hash)
          if constraint_version.key?(:comment)
            return constraint_version[:comment]
          end
        elsif constraint_version.is_a?(Array)
          constraint_version.each do |v|
            if v.is_a?(Hash) && v.key?(:value) && v[:value].to_s == target_version.to_s && v.key?(:comment)
              return v[:comment]
            end
          end
        end
        nil
      end
    end
  end
end
