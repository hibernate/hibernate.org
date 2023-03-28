require 'logger'

module Awestruct
  module Extensions
    module Links
      def execute(site)
        # keep reference to site
        @site = site
      end

      def reference_doc(project, series)
        return DocumentRef.from_patterns(project, series, :reference_doc)
      end

      def javadoc(project, series)
        return DocumentRef.from_patterns(project, series, :javadoc)
      end

      def getting_started_guide(project, series)
        return DocumentRef.from_patterns(project, series, :getting_started_guide)
      end

      def migration_guide(project, series)
        return DocumentRef.from_patterns(project, series, :migration_guide)
      end

      def maven_central_search_url(coord, version)
        if coord.artifact_id_pattern?
          search_string = ERB::Util.url_encode( "|ga|1|g:#{coord.group_id} AND a:#{coord.artifact_id_pattern} AND v:#{version}")
          return "#{@site.maven.repo.central.web_ui_url}/#search#{search_string}"
        else
          search_string = ERB::Util.url_encode( "|ga|1|g:#{coord.group_id} AND v:#{version}")
          return "#{@site.maven.repo.central.web_ui_url}/#search#{search_string}"
        end
      end

      def maven_central_artifact_url(group_id, artifact_id, version)
        gav_string = ERB::Util.url_encode( "|#{group_id}|#{artifact_id}|#{version}|")
        return "#{@site.maven.repo.central.web_ui_url}/#artifactdetails#{gav_string}"
      end

      def github_issues_url(project)
        return "https://github.com/hibernate/#{project.github['project']}/issues?q=is%3Aissue+is%3Aclosed+"
      end

      def jira_issues_for_series_url(project, series)
        versions = series.releases.collect{|r| r.version}
        return jira_issues_for_versions_url(project, versions)
      end

      def jira_issues_for_release_url(project, release)
        return jira_issues_for_versions_url(project, [release.version])
      end

      def jira_issues_for_versions_url(project, versions)
        fix_version_translator = _fix_version_translator(project)
        comma_separated_fix_versions = versions.collect{|v| fix_version_translator.call(v)}.join( "%2C%20" )
        return "https://hibernate.atlassian.net/issues/?jql=project%20%3D%20#{project.jira['key']}%20AND%20fixVersion%20in%20(#{comma_separated_fix_versions})%20ORDER%20BY%20updated"
      end

      def _fix_version_translator(project)
        return project.jira['key'] == 'HHH' ?
          lambda {|v| v != '4.2.0.Final' && v != '4.3.0.Final' && v != '5.0.0.Final' && v =~ /^(.*).Final$/ ? $1 : v }
          : lambda {|v| v}
      end

      def dist_sourceforge(project, series, release)
        return DistRef.from(project, series, release, :sourceforge)
      end

      def self._pattern_substitute(pattern, project, series = nil, release = nil)
        if pattern.nil?
          return nil
        end
        return pattern.gsub('{series.version}', series&.version || '')
            .gsub('{release.version}', release&.version || '')
            .gsub('{series.version.dashes}', series&.version&.gsub('.', '-') || '')
      end

      class DocumentRef
        @@logger = Logger.new(STDERR)
        @@logger.level = Logger::INFO

        def self.from_patterns(project, series, link_key)
          log_prefix = "#{project.name}/#{series.version}/#{link_key}: "
          link = series&.links&.[](link_key)
          link ||= project&.links&.[](link_key)
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
          latest_stable_only = link['latest_stable_only']
          if not latest_stable_only.nil? and latest_stable_only and not series.latest_stable
            @@logger.debug("#{log_prefix}Link is for the latest stable series only")
            return nil
          end
          latest_stable = link['latest_stable']
          if latest_stable and series.latest_stable
            link = latest_stable
            @@logger.debug("#{log_prefix}Link overridden for latest stable: #{link}")
          end
          html_pattern = link['html']
          pdf_pattern = link['pdf']
          @@logger.debug("#{log_prefix}Link patterns: #{html_pattern} / #{pdf_pattern}")
          html_url = Links._pattern_substitute(html_pattern, project, series)
          pdf_url = Links._pattern_substitute(pdf_pattern, project, series)
          @@logger.debug("#{log_prefix}Link URLs: #{html_url} / #{pdf_url}")
          if html_url.nil? and pdf_url.nil?
            return nil
          end
          return DocumentRef.new(html_url, pdf_url)
        end

        attr_reader :html_url, :pdf_url

        def initialize(html_url, pdf_url)
          @html_url = html_url
          @pdf_url = pdf_url
        end
      end

      class DistRef
        @@logger = Logger.new(STDERR)
        @@logger.level = Logger::INFO

        def self.from(project, series, release, link_key)
          log_prefix = "#{project.name}/#{series.version}/#{release&.version}/#{link_key}: "
          link = release&.links&.dist&.[](link_key)
          link ||= series&.links&.dist&.[](link_key)
          link ||= project&.links&.dist&.[](link_key)
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
          zip_url = Links._pattern_substitute(zip_pattern, project, series, release)
          @@logger.debug("#{log_prefix}Link URLs: #{zip_url}")
          if zip_url.nil?
            return nil
          end
          return DistRef.new(zip_url)
        end

        attr_reader :zip_url

        def initialize(zip_url)
          @zip_url = zip_url
        end
      end
    end
  end
end
