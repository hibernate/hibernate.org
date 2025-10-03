require 'logger'

module Awestruct
  module Extensions
    class LinkResolver
      def execute(site)
        @site = site

        site[:projects].each do |project_id, project|
            project[:release_series]&.each_value do |series|
              links = series['links'] || Hash.new
              series['links'] = links
              ['reference_doc', 'javadoc', 'migration_guide', 'short_guide', 'whats_new'].each do |key|
                links[key] = DocumentRef.from_patterns(project, series, key)
              end
              ['getting_started_guide'].each do |key|
                links[key] = DocumentRef.from_patterns_multi(project, series, key)
              end
              series[:releases]&.each do |release|
                links = release['links'] || Hash.new
                release['links'] = links
                links[:maven] = MavenRef.from(@site, project, series, release)
                links[:dist] ||= Hash.new
                links[:dist][:sourceforge] = DistRef.from(project, series, release, :sourceforge)
              end
            end
        end
      end

      def self._pattern_substitute(pattern, project, series = nil, release = nil)
        if pattern.nil?
          return nil
        end
        return pattern.gsub('{series.version}', series&.version || '')
            .gsub('{series.latest_scm_ref}', series&.latest_scm_ref || '')
            .gsub('{release.version}', release&.version || '')
            .gsub('{series.version.dashes}', series&.version&.gsub('.', '-') || '')
      end

      class MavenRef
        @@logger = Logger.new(STDERR)
        @@logger.level = Logger::INFO

        def self.from(site, project, series, release)
          log_prefix = "#{project['name']}/#{series.version}/#{release.version}: "
          project_maven = project['maven'] || {}
          series_maven = series['maven'] || {}
          release_maven = release['maven'] || {}
          maven_coord = release_maven&.[]('coord') || series_maven&.[]('coord') || project_maven['coord']
          @@logger.debug("#{log_prefix}Coord: #{maven_coord}")
          maven_signing = project_maven&.[]('signing')
          maven_repo = {}
          maven_repo[:releases] = MavenRepoRef.from( site, release_maven&.[]('repo')&.[]('releases') || series_maven&.[]('repo')&.[]('releases') || project_maven&.[]('repo')&.[]('releases') )
          maven_repo[:snapshots] = MavenRepoRef.from( site, release_maven&.[]('repo')&.[]('snapshots') || series_maven&.[]('repo')&.[]('snapshots') || project_maven&.[]('repo')&.[]('snapshots') )
          @@logger.debug("#{log_prefix}Repo: #{maven_repo}")
          maven_artifacts = release_maven&.[]('artifacts') || series_maven&.[]('artifacts') || project_maven['artifacts']
          @@logger.debug("#{log_prefix}Artifacts: #{maven_artifacts}")
          return MavenRef.new(maven_coord, maven_signing, maven_artifacts, maven_repo)
        end

        attr_reader :coord, :signing, :artifacts, :repo

        def initialize(coord, signing, artifacts, repo)
          @coord = coord
          @signing = signing
          @artifacts = artifacts
          @repo = repo
        end
      end

      class MavenRepoRef
        def self.from(site, id)
          data = site.maven.repo&.[](id)
          return MavenRepoRef.new(id, data)
        end

        attr_reader :id, :data

        def initialize(id, data)
          @id = id
          @data = data
        end

        def to_s
          @id
        end

        def web_ui_all_artifacts_url(coord, version)
          if @id != 'central'
            raise StandardError, "Cannot generate web UI artifact links for repository: #{@id}"
          end
          if coord['artifact_id_pattern']
            # The new Maven Central WebUI doesn't support artifact ID patterns, so we fall back to the old WebUI.
            search_string = ERB::Util.url_encode("g:#{coord['group_id']} AND a:#{coord['artifact_id_pattern']} AND v:#{version}")
            return "#{@data.old_web_ui_url}/search?q=#{search_string}"
          else
            search_string = ERB::Util.url_encode("g:#{coord['group_id']} v:#{version}")
            return "#{@data.web_ui_url}/search?q=#{search_string}&sort=name"
          end
        end

        def web_ui_artifact_url(group_id, artifact_id, version)
          if @id != 'central'
            raise StandardError, "Cannot generate web UI artifact links for repository: #{@id}"
          end
          return "#{@data.web_ui_url}/artifact/#{group_id}/#{artifact_id}/#{version}"
        end

        def direct_download_url(coord)
          group_id_path = coord['group_id'].gsub('.', '/')
          return "#{@data.repo_url}/#{group_id_path}/"
        end
      end

      class DocumentRef
        @@logger = Logger.new(STDERR)
        @@logger.level = Logger::DEBUG

        def self.from_patterns(project, series, link_key)
          log_prefix = "#{project['name']}/#{series.version}/#{link_key}: "
          link_root = series&.[]('links')&.[](link_key)
          link_root ||= project&.[]('links')&.[](link_key)
          return from_patterns_single(project, series, link_key, link_root)
        end

        def self.from_patterns_multi(project, series, link_key)
          log_prefix = "#{project['name']}/#{series.version}/#{link_key}: "
          link_root = series&.[]('links')&.[](link_key)
          link_root ||= project&.[]('links')&.[](link_key)
          links = []
          if link_root.kind_of?(Array)
            link_root.each do |link|
              links.push(from_patterns_single(project, series, link_key, link))
            end
          else
            links.push(from_patterns_single(project, series, link_key, link_root))
          end
          return links.compact
        end

        def self.from_patterns_single(project, series, link_key, link)
          log_prefix = "#{project['name']}/#{series.version}/#{link_key}: "
          if link.nil?
            @@logger.debug("#{log_prefix}Link is nil")
            return nil
          end
          displayed = link['displayed']
          if not displayed.nil? and not displayed
            @@logger.debug("#{log_prefix}Link is not displayed")
            return nil
          end
          latest_stable_only = link['latest_stable_only']
          if not latest_stable_only.nil? and latest_stable_only and not series.latest_stable
            @@logger.debug("#{log_prefix}Link is for the latest stable series only")
            return nil
          end
          name = link['name']
          @@logger.debug("#{log_prefix}Link name: #{name}")
          latest_stable = link['latest_stable']
          if latest_stable and series.latest_stable
            link = latest_stable
            @@logger.debug("#{log_prefix}Link overridden for latest stable: #{link}")
          end
          html_pattern = link['html']
          pdf_pattern = link['pdf']
          @@logger.debug("#{log_prefix}Link patterns: #{html_pattern} / #{pdf_pattern}")
          html_url = LinkResolver._pattern_substitute(html_pattern, project, series)
          pdf_url = LinkResolver._pattern_substitute(pdf_pattern, project, series)
          @@logger.debug("#{log_prefix}Link URLs: #{html_url} / #{pdf_url}")
          if html_url.nil? and pdf_url.nil?
            return nil
          end
          return DocumentRef.new(name, html_url, pdf_url)
        end

        attr_reader :name, :html_url, :pdf_url

        def to_json(*args)
          {:name => @name, :html_url => @html_url, :pdf_url => @pdf_url}
              .compact
              .to_json(*args)
        end

        def initialize(name, html_url, pdf_url)
          @name = name
          @html_url = html_url
          @pdf_url = pdf_url
        end
      end

      class DistRef
        @@logger = Logger.new(STDERR)
        @@logger.level = Logger::INFO

        def self.from(project, series, release, link_key)
          log_prefix = "#{project['name']}/#{series.version}/#{release&.version}/#{link_key}: "
          link = release&.[]('links')&.[]('dist')&.[](link_key)
          link ||= series&.[]('links')&.[]('dist')&.[](link_key)
          link ||= project&.[]('links')&.[]('dist')&.[](link_key)
          if link.nil?
            @@logger.debug("#{log_prefix}Link is nil")
            return nil
          end
          @@logger.debug("#{log_prefix}Link is #{link}")
          displayed = link['displayed']
          if not displayed.nil? and not displayed
            @@logger.debug("#{log_prefix}Link is not displayed")
            return nil
          end
          zip_pattern = link['zip']
          @@logger.debug("#{log_prefix}Link patterns: #{zip_pattern}")
          zip_url = LinkResolver._pattern_substitute(zip_pattern, project, series, release)
          @@logger.debug("#{log_prefix}Link URLs: #{zip_url}")
          if zip_url.nil?
            return nil
          end
          return DistRef.new(zip_url)
        end

        attr_reader :zip_url

        def to_json(*args)
          {:zip_url => @zip_url}.to_json(*args)
        end

        def initialize(zip_url)
          @zip_url = zip_url
        end
      end
    end
  end
end
