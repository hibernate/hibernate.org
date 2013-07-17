require 'wget_wrapper'
require 'js_minifier'
require 'css_minifier'
require 'html_minifier'
require 'file_merger'
require 'less_config'

Awestruct::Extensions::Pipeline.new do
  development = Engine.instance.site.profile == 'development'
  # Example of extension only available for certain profiles
  unless development
  #  execute extension only in prod
  end
  helper Awestruct::Extensions::Partial
  helper Awestruct::Extensions::GoogleAnalytics
  helper Awestruct::Extensions::Relative
  extension Awestruct::Extensions::WgetWrapper.new
  transformer Awestruct::Extensions::JsMinifier.new
  transformer Awestruct::Extensions::CssMinifier.new
  transformer Awestruct::Extensions::HtmlMinifier.new
  extension Awestruct::Extensions::FileMerger.new
  extension Awestruct::Extensions::LessConfig.new
  extension Awestruct::Extensions::Indexifier.new
end

