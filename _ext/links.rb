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
