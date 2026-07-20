require 'cssminify'

##
#
# Awestruct::Extensions:CssMinifier is a transformer type of awestruct extension.
# If configured in project pipeline and site.yml, it will compress CSS files.
#
# Required installed gems:
# - cssminify
#
# Configuration:
#
# 1. configure the extension in the project pipeline.rb:
#    - add css_minifier dependency:
#
#      require 'css_minifier'
#
#    - put the extension initialization in the initialization itself:
#
#      transformer Awestruct::Extensions::CssMinifier.new
#
# 2. In your site.yml add:
#
#    css_minifier: enabled
#
#    This setting is optional and defaults to enabled.
#
##
module Awestruct
  module Extensions
    class CssMinifier

      def transform(site, page, input)

        # Checking if 'css_minifier' setting is provided and whether it's enabled.
        # By default, if it's not provided, we imply it's enabled.
        if !site.css_minifier.nil? and !site.css_minifier.to_s.eql?('enabled')
          return input
        end

        # Test if it's a CSS file.
        ext = File.extname(page.output_path)
        if !ext.empty?

          ext_txt = ext[1..-1]

          # Filtering out non-css files and those which were already minimized with added suffix.
          if ext_txt == "css" and !page.output_path.to_s.end_with?("min.css")
            print "Minifying css #{page.output_path} \n"
            output = CSSminify.compress(input)

            # Write minified version directly to the output directory
            minOutputPath = File.join(site.config.output_dir, page.output_path.to_s.sub(/\.css$/, '.min.css'))
            FileUtils.mkdir_p(File.dirname(minOutputPath))
            File.write(minOutputPath, output)
          else
            return input
          end
        end

        # We return the input because we leave the original file untouched
        input
      end
    end
  end
end
