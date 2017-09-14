module Awestruct
  module Extensions
    module Releases

      def latest_stable_release(p = page)
        project = site.projects[p.project]
        return project.latest_stable_release
      end

      def latest_release(p = page)
        project = site.projects[p.project]
        return project.latest_release
      end

      def latest_stable_series(p = page)
        project = site.projects[p.project]
        return project.latest_stable_series
      end

      def latest_series(p = page)
        project = site.projects[p.project]
        return project.latest_series
      end
    end
  end
end
