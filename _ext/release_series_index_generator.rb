require 'fileutils'

module Awestruct
  module Extensions
    # Extension that automatically generates index pages for release series
    # that have a series.yml but no index.adoc in the source tree
    class ReleaseSeriesIndexGenerator

      def execute(site)
        # Find all projects and their series that need generated index pages
        projects = Dir.glob('_data/projects/*/releases/*/series.yml').map do |series_file|
          project_path = series_file.split('/')[2]
          series_version = series_file.split('/')[4]
          index_path = "#{project_path}/releases/#{series_version}/index.adoc"

          # Only create if index.adoc doesn't exist in the source
          unless File.exist?(index_path)
            { project: project_path, series: series_version, path: index_path }
          end
        end.compact

        # Generate pages using temporary files
        projects.each do |info|
          create_page_from_temp(site, info[:project], info[:series], info[:path])
        end

        site
      end

      private

      def create_page_from_temp(site, project, series_version, output_path)
        # Create temporary directory
        tmp_dir = './_tmp/release_series_indexes'
        FileUtils.mkdir_p(tmp_dir)

        # Generate the index.adoc content
        content = <<~ADOC
          :awestruct-layout: project-releases-series
          :awestruct-project: #{project}
          :awestruct-series_version: "#{series_version}"
        ADOC

        # Create a temporary file
        tmp_file = File.join(tmp_dir, "#{project}-#{series_version}.adoc")
        File.write(tmp_file, content)

        # Load the temporary file as an Awestruct page
        page = site.engine.load_page(tmp_file)
        # Set output path: orm/releases/3.0/index.adoc -> /orm/releases/3.0/index.html
        page.output_path = '/' + output_path.sub(/\.adoc$/, '.html')

        # Add to site pages
        site.pages << page
      end
    end
  end
end
