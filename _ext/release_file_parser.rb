require 'nokogiri'
require 'open-uri'
require 'uri'
require 'fileutils'

module Awestruct
  module Extensions
    # Awestrcut extension which traverses the given directory to find release files,
    # making the release information available in a hash.
    #
    # The assumption is that release files are in a directory called 'releases', the
    # parent directory is the named after the project and the release files themselves
    # are YAML files.
    #
    # The release information for a given release can then be accessed, starting from the
    # top level site hash via:
    # site['projects'].['<project-name>'].['releases'].['<release-version>'], eg site['projects'].['validator'].['releases'].['5.0.0.Final'].
    #
    # The release data itself is stored in the hash using at the moment the following keys:
    # version, version_family, date, stable announcement_url,summary and displayed
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
        if @projects_hash.nil?
           @projects_hash = Hash.new
           site[:projects] = @projects_hash
        end

        # traverse the file system to find the release files and create the hashes
        findReleaseData( "#{site.dir}/#{@data_dir}" )

        # also create a sorted array for the releases
        createSortedReleaseHash
      end

      def findReleaseData(dir)
        Dir[ "#{dir}/*" ].each do |entry|
          if ( File.directory?( entry ) )
            if ( entry =~ /releases/ )
              project_name = getProjectName( entry )
              group_id, artifact_id = getGAInfo( project_name )

              project_hash = @projects_hash[project_name]
              if project_hash.nil?
                project_hash = Hash.new
                @projects_hash[project_name] = project_hash
              end

              releases_hash = Hash.new
              project_hash[:releases] = releases_hash

              createReleaseHashes( entry, releases_hash, group_id, artifact_id)
            else
              findReleaseData( entry )
            end
          end
        end
      end

      def getProjectName(dir)
        parent_dir = File.dirname( dir )
        project_name = File.basename( parent_dir )
      end

      def getGAInfo(project)
        case project
          when 'ogm'
            group_id = 'org.hibernate.ogm'
            artifact_id = 'hibernate-ogm-core'
          when 'orm'
            group_id = 'org.hibernate'
            artifact_id = 'hibernate-core'
          when 'search'
            group_id = 'org.hibernate'
            artifact_id = 'hibernate-search'
          when 'validator'
            group_id = 'org.hibernate'
            artifact_id = 'hibernate-validator'
        end
        return group_id, artifact_id
      end

      def createReleaseHashes( release_dir, project_hash, group_id, artifact_id )
        Dir.foreach(release_dir) do |file|
          # skip '.' and '..'
          if ( File.directory?( file ) )
            next
          end

          if !(file =~ /.*\.yml$/)
            abort("The release file #{file} does not have the YAML (.yml) extension!")
          end

          # load the release data
          releaseHash = @site.engine.load_yaml( File.expand_path( file, release_dir ) )
          if( group_id != nil && artifact_id != nil)
            releaseHash['dependencies'] = ReleaseDependencies.new(@site, group_id, artifact_id, releaseHash['version'])
          end

          # use a regexp to get the file name without extension into the pattern buffer.
          # file name == version
          File.basename( file ) =~ /^(.*)\.\w*$/
          # use the file (release) name as key
          key = $1.to_s
          project_hash[ key ] = releaseHash
          end
      end

      def createSortedReleaseHash
        @site.projects.each do |projectname, project|
          releases = project[:releases]
          unless releases.nil?
            sortedReleases = Hash[releases.sort_by { |key, value| Version.new(key) }.reverse]
            @site.projects[projectname][:sorted_releases] = sortedReleases.values
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

    # Helper class to retrieve the dependencies of a release by parsing the release POM
    class ReleaseDependencies
      Nexus_base_url = 'https://repository.jboss.org/nexus/content/repositories/public/'

      def initialize(site, group_id, artifact_id, version)
        # init instance variables
        @properties = Hash.new
        @dependencies = Hash.new
        @site = site

        # try loading the pom
        uri = get_uri(group_id, artifact_id, version)
        doc = create_doc(uri)
        unless doc.nil?
          if has_parent(doc)
            # parent pom needs to be loaded first
            parent_uri = get_uri(doc.xpath('//parent/groupId').text, doc.xpath('//parent/artifactId').text, doc.xpath('//parent/version').text)
            parent_doc = create_doc(parent_uri)
            process_doc(parent_doc)
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
      def create_doc(uri)
        # make sure _tmp dir exists
        tmp_dir = File.join(File.dirname(__FILE__), '..', '_tmp')
        unless File.directory?(tmp_dir)
          p "creating #{tmp_dir}"
          FileUtils.mkdir_p(tmp_dir)
        end

        pom_name = uri.sub(/.*\/([\w\-\.]+\.pom)$/, '\1')
        # to avoid net access cache the downloaded POMs into the _tmp directory
        cached_pom = File.join(tmp_dir, pom_name)
        if File.exists?(cached_pom)
          f = File.open(cached_pom)
          doc = Nokogiri::XML(f)
          f.close
        else
          begin
            doc = Nokogiri::XML(open(uri))
            # cache the pom
            File.open(cached_pom, 'w') { |f| f.print(doc.to_xml) }
          rescue => error
            $LOG.warn "Release POM #{uri.split('/').last} not locally cached and unable to retrieve it from JBoss Nexus"
            if @site.profile == 'production'
              abort "Aborting site generation, since the production build requires the release POM information"
            else
              $LOG.warn "Continue build since we are building the '#{@site.profile}' profile. Note that variables interpolated from the release poms will not display\n"
              return nil
            end
          end
        end
        doc.remove_namespaces!
      end

      def process_doc(doc)
        load_properties(doc)
        extract_dependencies(doc)
      end

      def get_uri(group_id, artifact, version)
        Nexus_base_url + group_id.gsub(/\./, "/") + '/' + artifact + '/' + version + '/' + artifact + '-' + version + '.pom'
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
