module Awestruct
  module Extensions
    module GoogleAnalytics4

      def google_analytics(options={})
        options = defaults(options)

        html = ''
        html += %Q(<!-- Google tag (gtag.js) -->\n)
        html += %Q(<script async src="https://www.googletagmanager.com/gtag/js?id=#{options[:id]}"></script>\n)
        html += %Q(<script>\n)
        html += %Q(  window.dataLayer = window.dataLayer || [];\n)
        html += %Q(  function gtag(){dataLayer.push(arguments);}\n)
        html += %Q(  gtag('js', new Date());\n)
        html += %Q(\n)
        html += %Q(  gtag('config', '#{options[:id]}');\n)
        html += %Q(</script>\n)

        html
      end

      private

      def defaults(options)
        options = site.google_analytics.merge(options) if site.google_analytics.is_a?(Hash)
        options = Hash[options.map{ |k, v| [k.to_sym, v] }]

        options
      end
    end
  end
end
