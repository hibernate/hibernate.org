module Awestruct
  module Extensions
    module DirectoryListing

      def list_entries(dir, pattern)
        table = Array.new
        Dir.glob(File.join(dir, pattern)) do |file_name|
          file_data = Array.new
          file_data.push File.basename(file_name)
          file_data.push File.mtime(file_name).asctime
          file_size = File.size(file_name)
          if file_size > 1024
            file_size = "#{file_size / 1024}K"
          end
          file_data.push file_size
          table.push file_data
        end
        return table
      end

    end
  end
end
