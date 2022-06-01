require 'nokogiri'
require 'open-uri'
require 'uri'
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
        if @projects_hash == nil
           @projects_hash = Hash.new
           site[:projects] = @projects_hash
        end

        # traverse the file system to find the release information
        findReleaseFiles( site, "#{site.dir}/#{@data_dir}" )
      end

      def findReleaseFiles(site, dir)
        Dir[ "#{dir}/*" ].each do |entry|
          if ( File.directory?( entry ) )
            if ( entry =~ /releases/ )
              project = getProject( entry )

              releases_hash = project[:releases]
              if ( releases_hash == nil )
                releases_hash = Hash.new
                project[:releases] = releases_hash
              end
              
              release_series_hash = project[:release_series]
              if ( release_series_hash == nil )
                release_series_hash = Hash.new
                project[:release_series] = release_series_hash
              end

              populateReleaseHashes( entry, release_series_hash, releases_hash )
              
              sortReleaseHashes( project )
              
              downloadDependencies( project, release_series_hash.values )
            else
              findReleaseFiles( site, entry )
            end
          end
        end
      end
      
      def getProject(sub_dir)
        parent_dir = File.dirname( sub_dir )
        project_id = File.basename( parent_dir )

        project = @projects_hash[project_id]
        if project == nil
          project = Hash.new
          @projects_hash[project_id] = project
        end
        
        if (project[:id] == nil)
          project[:id] = project_id
        end
        
        return project
      end

      def populateReleaseHashes(releases_dir, release_series_hash, release_hash)
        Dir.foreach(releases_dir) do |file_name|
          file = File.expand_path( file_name, releases_dir )
          # skip '.' and '..'
          if ( file_name.start_with?( "." ) )
            next
          else
            # This directory represents a release series
            series = createSeries( file )
            release_series_hash[series.version] = series

            # Populate this series' releases
            Dir.foreach(file) do |sub_file_name|
             sub_file = File.expand_path( sub_file_name, file )
              # skip '.' and '..' and 'series.yml'
              if ( File.directory?( sub_file ) || File.basename( sub_file ) == "series.yml" )
                next
              else
                release = createRelease( sub_file, series )
                series.releases.push( release )
                release_hash[release.version] = release
              end
            end
          end
        end
      end

      def createSeries(series_dir)
        series_file = File.expand_path( "./series.yml", series_dir )
        series = @site.engine.load_yaml( series_file )
        if ( series[:version] == nil )
          series[:version] = File.basename( series_dir )
        end
        series[:releases] = Array.new
        return series
      end

      def createRelease(release_file, series)
        unless ( release_file =~ /.*\.yml$/ )
          abort( "The release file #{release_file} does not have the YAML (.yml) extension!" )
        end

        release = @site.engine.load_yaml( release_file )
        
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
          raise "Unsupported version scheme for #{release_file}: #{release.version}"
        end
        
        return release
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
            series.latest = false
            series.latest_stable = false

            if !found_series
              found_series = true
              series.latest = true
              project[:latest_series] = series
            end
            if !found_stable_series && series.stable
              found_stable_series = true
              series.latest_stable = true
              project[:latest_stable_series] = series
            end
          end
        end
      end

      def downloadDependencies(project, series)
        project_maven = project[:maven]
        if ( project_maven.nil? )
          return
        end
        series.each do |series|
          series_maven = series[:maven] || {}
          if ( series.displayed.nil? || series.displayed )
            release = series.releases.first
            release_maven = release[:maven] || {}
            group_id = release_maven[:group_id]
            group_id ||= series_maven[:group_id]
            group_id ||= project_maven[:group_id]
            main_artifact_id = release_maven[:main_artifact_id]
            main_artifact_id ||= series_maven[:main_artifact_id]
            main_artifact_id ||= project_maven[:main_artifact_id]
            if ( group_id != nil && main_artifact_id != nil )
              # Only download dependencies for the latest release in the series
              release.dependencies = ReleaseDependencies.new(@site, group_id, main_artifact_id, release.version)
            end
          end
        end
      end
    end
            
    # Custom version class able to understand and compare the project versions of Hibernate projects
    class Version
      include Comparable

      attr_reader :major, :feature_group, :feature, :bugfix

      def initialize(version="")
        v = version.to_s.split(".")
        @major = v[0].to_i
        @feature_group = v[1].to_i
        @feature = v[2].to_i
        @bugfix = v[3] == nil ? nil : VersionBugfix.new(v[3])
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

    class VersionBugfix
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

    # Helper class to retrieve the dependencies of a release by parsing the release POM
    class ReleaseDependencies
      def initialize(site, group_id, artifact_id, version)
        # init instance variables
        @properties = Hash.new
        @dependencies = Hash.new
        @site = site

        # try loading the pom
        doc = create_doc(group_id, artifact_id, version)
        unless doc == nil
          if has_parent(doc)
            # parent pom needs to be loaded first
            parent_doc = create_doc(doc.xpath('//parent/groupId').text, doc.xpath('//parent/artifactId').text, doc.xpath('//parent/version').text)
            unless parent_doc == nil
              process_doc(parent_doc)
            end
          end
          process_doc(doc)
        end
      end

      def get_value(property)
        @properties[property]
      end

      def get_version(group_id, artifact_id)
        @dependencies[group_id + ':' + artifact_id]
      end

      private
      def create_doc(group_id, artifact_id, version)
        # make sure _tmp dir exists
        tmp_dir = File.join(File.dirname(__FILE__), '..', '_tmp')
        unless File.directory?(tmp_dir)
          p "creating #{tmp_dir}"
          FileUtils.mkdir_p(tmp_dir)
        end

        gav = "#{group_id}:#{artifact_id}:#{version}"
        pom_name = get_pom_name(group_id, artifact_id, version)
        # to avoid net access cache the downloaded POMs into the _tmp directory
        cached_pom = File.join(tmp_dir, pom_name)
        if File.exists?(cached_pom)
          $LOG.info "Cache hit: #{gav}" if $LOG.info?
          f = File.open(cached_pom)
          doc = Nokogiri::XML(f)
          f.close
        else
          begin
            # try to download the pom from Central
            doc = download_pom(@site.maven.repo.central.repo_url, group_id, artifact_id, version, cached_pom)
          rescue => maven_error
            $LOG.warn "Error downloading #{gav} from Maven Central: #{maven_error.message}"
            # if it fails, it might be because it wasn't synced yet so let's try to download it from JBoss Nexus
            begin
              doc = download_pom(@site.maven.repo.jboss.repo_url, group_id, artifact_id, version, cached_pom)
            rescue => jboss_nexus_error
              $LOG.warn "Error downloading #{gav} from JBoss Nexus: #{jboss_nexus_error.message}"
              # last resort, try bintray
              begin
                doc = download_pom(@site.maven.repo.bintray.repo_url, group_id, artifact_id, version, cached_pom)
              rescue => bintray_error
                $LOG.warn "Error downloading #{gav} from Bintray: #{bintray_error.message}"
                $LOG.warn "Release POM #{gav} not locally cached and unable to retrieve it from Central, from JBoss Nexus or from Bintray"
                if @site.profile == 'production'
                  $LOG.error maven_error.message + "\n " + maven_error.backtrace.join("\n ")
                  abort "Aborting site generation, since the production build requires the release POM information"
                else
                  $LOG.warn maven_error.message + "\n " + maven_error.backtrace.join("\n ")
                  $LOG.warn "Continuing build since we are building the '#{@site.profile}' profile. Note that variables interpolated from the release poms will not display\n"
                  return nil
                end
              end
            end
          end
        end
        doc.remove_namespaces!
      end

      def download_pom(base_url, group_id, artifact_id, version, cached_pom)
        uri = get_uri(base_url, group_id, artifact_id, version)
        $LOG.info "Downloading: #{uri.to_s}" if $LOG.info?
        doc = Nokogiri::XML(URI.open(uri))
        File.open(cached_pom, 'w') { |f| f.print(doc.to_xml) }
        doc
      end

      def process_doc(doc)
        load_properties(doc)
        extract_dependencies(doc)
      end

      def get_uri(base_url, group_id, artifact, version)
        base_url + group_id.gsub(/\./, "/") + '/' + artifact + '/' + version + '/' + get_pom_name(group_id, artifact, version)
      end

      def get_pom_name(group_id, artifact, version)
        artifact + '-' + version + '.pom'
      end

      def has_parent(doc)
        !doc.xpath('//parent').empty?
      end

      def load_properties(doc)
        doc.xpath('//properties/*') .each do |property|
          key = property.name
          value = property.text
          @properties[key] = value
        end
      end

      def extract_dependencies(doc)
        doc.xpath('//dependency') .each do |dependency|
          group_id = dependency.xpath('./groupId').text
          artifact_id = dependency.xpath('./artifactId').text
          version = dependency.xpath('./version').text
          if ( version =~ /\$\{(.*)\}/ )
            version = @properties[$1]
          end
          key = group_id + ':' + artifact_id
          if @dependencies[key] == nil
            @dependencies[key] = version
          end
        end
      end
    end
  end
end
