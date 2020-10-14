require 'logger'

module Awestruct
  module Extensions
    module Links
      def execute(site)
        # keep reference to site
        @site = site
      end

      def doc_reference_url(project, series)
        suffix = series[:reference_doc_path]
        suffix ||= project.reference_doc_path
        return suffix.nil? ? nil : "#{doc_root_series_url(project, series)}#{suffix}"
      end

      def doc_reference_pdf_url(project, series)
        suffix = series[:reference_doc_pdf_path]
        suffix ||= project.reference_doc_pdf_path
        return suffix.nil? ? nil : "#{doc_root_series_url(project, series)}#{suffix}"
      end

      def javadoc_url(project, series)
        suffix = series[:javadoc_path]
        suffix ||= project.javadoc_path
        return suffix.nil? ? nil : "#{doc_root_series_url(project, series)}#{suffix}"
      end

      def doc_root_series_url(project, series)
        if series.latest_stable
          return project.stable_reference_doc_prefix_url
        else
          return "#{project.reference_doc_prefix_url}#{series.version}/"
        end
      end

      def doc_root_url(project)
        return project.reference_doc_prefix_url
      end

      def getting_started_guide(project, series)
        return DocumentRef.from_patterns(project, series, :getting_started_guide)
      end

      def migration_guide(project, series)
        return DocumentRef.from_patterns(project, series, :migration_guide)
      end

      def maven_central_search_url(group_id_pattern, artifact_id_pattern, version_pattern)
        search_string = ERB::Util.url_encode( "|ga|1|g:#{group_id_pattern} AND a:#{artifact_id_pattern} AND v:#{version_pattern}")
        return "#{@site.maven.repo.central.web_ui_url}/#search#{search_string}"
      end

      def maven_jboss_search_url(group_id_pattern, artifact_id_pattern, version_pattern)
        return "#{@site.maven.repo.jboss.web_ui_url}#nexus-search;gav~#{group_id_pattern}~#{artifact_id_pattern}~#{version_pattern}~~"
      end

      def maven_bintray_url(package)
        return "#{@site.maven.repo.bintray.web_ui_url}/artifacts/#{package}"
      end

      def maven_bintray_version_url(package, version)
        return "#{@site.maven.repo.bintray.web_ui_url}/artifacts/#{package}/#{version}"
      end

      def maven_central_artifact_url(group_id, artifact_id, version)
        gav_string = ERB::Util.url_encode( "|#{group_id}|#{artifact_id}|#{version}|")
        return "#{@site.maven.repo.central.web_ui_url}/#artifactdetails#{gav_string}"
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

      # Accepts a project description (YML) and a release (YML) and return the Sourceforge URL to the zip download
      def sourceforge_zip_url(project, release)
        # this if clause is not idiomatic to Ruby : TODO improve
        if release.sourceforge_url.instance_of? String
          sourceforge_url = release.sourceforge_url
        else
          sourceforge_url = project.sourceforge_url
        end
        return "#{sourceforge_url}#{release.version}/#{project.zip_file}/download".gsub('VERSION', release.version)
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
          html_pattern = link['html']
          pdf_pattern = link['pdf']
          @@logger.debug("#{log_prefix}Link patterns: #{html_pattern} / #{pdf_pattern}")
          html_url = _pattern_substitute(html_pattern, project, series)
          pdf_url = _pattern_substitute(pdf_pattern, project, series)
          @@logger.debug("#{log_prefix}Link URLs: #{html_url} / #{pdf_url}")
          if html_url.nil? and pdf_url.nil?
            return nil
          end
          return DocumentRef.new(html_url, pdf_url)
        end
        def self._pattern_substitute(pattern, project, series)
          if pattern.nil?
            return nil
          end
          return pattern.gsub('{series.version}', series.version)
              .gsub('{series.version.dashes}', series.version.gsub('.', '-'))
        end

        attr_reader :html_url, :pdf_url

        def initialize(html_url, pdf_url)
          @html_url = html_url
          @pdf_url = pdf_url
        end
      end
    end
  end
end
