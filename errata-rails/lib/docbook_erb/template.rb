# :simplecov_exclude:
#
# Used in publican.rake to build Main.xml from Main.erb
#
# See also helpers.rb
#
module DocbookErb

  class Template
    include Helpers

    def initialize(erb_file, book_name, md_output_dir)
      @erb_file = erb_file
      @book_name = book_name
      @md_output_dir = md_output_dir

      # The "@output" arg is required for concat_output to work
      @erb = ERB.new(File.read(@erb_file), nil, nil, "@output")
    end

    def concat_output(content)
      @output.concat(content)
    end

    def render
      @erb.result(binding)
    end

    def render_to_file(output_file)
      File.open(output_file, 'w') { |file| file.write(self.render) }
    end

  end
end
