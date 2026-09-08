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

      def integration_constraint(constraint, link_prefix = nil)
        version = constraint[:version]
        if version.nil?
          return nil
        end
        if version.is_a?(Array)
          rendered = version.map { |v| integration_constraint_version(v, true, link_prefix) }
          if rendered.length <= 1
            rendered.join
          elsif rendered.length == 2
            rendered.join(" or ")
          else
            rendered[0..-2].join(", ") + " or " + rendered[-1]
          end
        else
          integration_constraint_version(version, true, link_prefix)
        end
      end

      def integration_constraint_version(version, includeComment = true, link_prefix = nil)
        if version.is_a?(Hash)
          if version.key?(:from)
            "#{integration_constraint_version(version[:from], includeComment, link_prefix)}&nbsp;&rarr;&nbsp;#{integration_constraint_version(version[:to], includeComment, link_prefix)}" +
              (includeComment && version.key?(:comment) ? " (#{version[:comment]})" : "")
          else
            val = version[:value].to_s
            rendered_val = link_prefix ? "link:#{link_prefix}#{val}/[#{val}]" : val
            rendered_val + (includeComment && version.key?(:comment) ? " (#{version[:comment]})" : "")
          end
        else
          val = version.to_s
          link_prefix ? "link:#{link_prefix}#{val}/[#{val}]" : val
        end
      end
    end
  end
end
