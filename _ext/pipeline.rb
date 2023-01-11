require 'js_minifier'
require 'css_minifier'
require 'html_minifier'
require 'google_analytics_4'
require 'relative'
require 'releases'
require 'release_file_parser'
require 'redirect_creator'
require 'directory_listing'
require 'links'

# dependencies for asciidoc support
require 'tilt'
require 'haml'
require 'asciidoctor'

# hack to add asciidoc support in HAML
# remove once haml_contrib has accepted the asciidoc registration patch
# :asciidoc
#   some block content
#
# :asciidoc
#   :doctype: inline
#   some inline content
#
if !Haml::Filters.constants.map(&:to_s).include?('AsciiDoc')
  Haml::Filters.register_tilt_filter 'AsciiDoc', :template_class => ::Tilt::AsciidoctorTemplate
  Haml::Filters::AsciiDoc.options[:safe] = :safe
  Haml::Filters::AsciiDoc.options[:attributes] ||= {}
  Haml::Filters::AsciiDoc.options[:attributes]['notitle!'] = ''
  # copy attributes from site.yml
  attributes = site.asciidoctor[:attributes].each do |key, value|
    Haml::Filters::AsciiDoc.options[:attributes][key] = value
  end
end

Awestruct::Extensions::Pipeline.new do
  # register helpers to be used in templates
  helper Awestruct::Extensions::Partial
  helper Awestruct::Extensions::GoogleAnalytics4
  helper Awestruct::Extensions::Relative
  helper Awestruct::Extensions::Releases
  helper Awestruct::Extensions::DirectoryListing
  helper Awestruct::Extensions::Links

  # register extensions and transformers
  extension Awestruct::Extensions::ReleaseFileParser.new
  transformer Awestruct::Extensions::JsMinifier.new
  transformer Awestruct::Extensions::CssMinifier.new
  transformer Awestruct::Extensions::HtmlMinifier.new
  extension Awestruct::Extensions::Indexifier.new([/^.*\/reactive\/documentation\/\d+\.\d+\/\.*/])

  development = Engine.instance.site.profile == 'development'
  if not development
    extension Awestruct::Extensions::RedirectCreator.new "redirects", "hib-docs-reference-redirects", "hib-docs-v3-api-redirects"
  end
end

