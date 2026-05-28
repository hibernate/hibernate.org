require 'logger'

module Awestruct
  module Extensions
    module Links
      def execute(site)
        # keep reference to site
        @site = site
      end

      def doc(project, series)
        return series&.[](:links)&.[](:doc)
      end

      def reference_doc(project, series)
        return series&.[](:links)&.[](:reference_doc)
      end

      def javadoc(project, series)
        return series&.[](:links)&.[](:javadoc)
      end

      def getting_started_guides(project, series)
        return series&.[](:links)&.[](:getting_started_guide)
      end

      def migration_guide(project, series)
        return series&.[](:links)&.[](:migration_guide)
      end

      def short_guide(project, series)
        return series&.[](:links)&.[](:short_guide)
      end

      def whats_new(project, series)
        return series&.[](:links)&.[](:whats_new)
      end

      def maven(project, series, release)
        return release&.[](:links)&.[](:maven)
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
        return release&.[](:links)&.[](:dist)&.[](:sourceforge)
      end
    end
  end
end
