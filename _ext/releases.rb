module Awestruct
  module Extensions
    module Releases

      def latest_stable_release(p = page)
        releases = site.projects[p.project].releases
        # releases are ordered by latest first in the metadata
        releases.each do |release|
          if release.stable
            return release
          end
        end
        return Nil
      end

      def latest_dev_release(p = page)
        releases = site.projects[p.project].releases
        # releases are ordered by latest first in the metadata
        releases.each do |release|
          if not release.stable
            return release
          end
        end
        return Nil
      end
    end
  end
end
