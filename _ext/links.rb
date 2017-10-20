module Awestruct
  module Extensions
    module Links
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

      def jboss_nexus_search_url(group_id_pattern, artifact_id_pattern, version_pattern)
        return "https://repository.jboss.org/nexus/index.html#nexus-search;gav~#{group_id_pattern}~#{artifact_id_pattern}~#{version_pattern}~~"
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
    end
  end
end
