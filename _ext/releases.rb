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

      def next_dev_series(p = page)
        project = site.projects[p.project]
        return project.next_dev_series
      end

      def series(p = page, version)
        project = site.projects[p.project]
        return project.release_series[version]
      end

      def integration_constraint(constraint)
        version = constraint[:version]
        if version.nil?
          return nil
        end
        if version.is_a?(Array)
          rendered = version.map { |v| integration_constraint_version(v) }
          if rendered.length <= 1
            rendered.join
          elsif rendered.length == 2
            rendered.join(" or ")
          else
            rendered[0..-2].join(", ") + " or " + rendered[-1]
          end
        else
          integration_constraint_version(version)
        end
      end

      def integration_constraint_version(version, includeComment = true)
        if version.is_a?(Hash)
          if version.key?(:from)
            "#{integration_constraint_version(version.from, includeComment)} &rarr; #{integration_constraint_version(version.to, includeComment)}" +
              (includeComment && version.key?(:comment) ? " (#{version.comment})" : "")
          else
            version.value.to_s + (includeComment && version.key?(:comment) ? " (#{version.comment})" : "")
          end
        else
          version.to_s
        end
      end
    end
  end
end
