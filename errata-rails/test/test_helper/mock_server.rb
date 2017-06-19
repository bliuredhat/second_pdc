module TestHelper
  # This class helps to load a set of mock files into a mock server.
  #
  # Please avoid dependencies on the Rails environment or libraries
  # here, as the class is intended to be used from a standalone ruby
  # script to launch a mock server, which may be run from a
  # different host.
  class MockServer
    def self.parse_mock(data)
      lines = data.lines
      in_meta = true
      (meta_lines,content_lines) = lines.partition do |line|
        if !in_meta
          false
        elsif line =~ %r{^//}
          true
        else
          in_meta = false
        end
      end

      mock = meta_lines.inject({}) do |h,line|
        if line =~ %r{^//\s*([^:]+):\s*(.+)$}
          h[$1.downcase.to_sym] = $2
        end
        h
      end

      mock[:content] = content_lines.join
      return mock
    end

    def self.mock_data_path
      File.expand_path File.join(File.dirname(__FILE__), '..', 'data', 'mocks')
    end

    def self.mock_data_files
      # Find everything under the mock data path (currently assumed JSON only)
      Dir[self.mock_data_path + '/**/*.json'].
        # exclude some editor backup files etc.  (I would like to use
        # git check-ignore but it's too new.)
        reject{|x| x =~ %r{~$}}.
        select(&File.method(:file?))
    end

    def self.parse_all_mocks
      self.mock_data_files.
        map{|filename| [filename, File.read(filename)]}.
        map{|(filename, data)| self.parse_mock(data).merge(:source => filename)}.
        select{|mock| mock.include?(:path)}
    end
  end
end
