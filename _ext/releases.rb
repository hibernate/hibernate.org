module Awestruct
  module Extensions
    module Releases

      def latest_stable_release(p = page)
        releases = site.projects[p.project].sorted_releases

        if releases.nil?
          return nil
        end

        # releases are ordered by latest first in the metadata
        releases.each do |release|
          if release.stable
            return release
          end
        end
        return nil
      end

      def latest_dev_release(p = page)
        releases = site.projects[p.project].sorted_releases

        if releases.nil?
          return nil
        end

        # releases are ordered by latest first in the metadata
        releases.each do |release|
          if not release.stable
            return release
          end
        end
        return nil
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
