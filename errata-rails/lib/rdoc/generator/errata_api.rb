# :simplecov_exclude:
require 'rdoc'

#
# Generator for Errata Tool's HTTP API documentation.
#
# Adding the :api-url: directive (with a URL) into an rdoc comment
# flags the current code object as part of the HTTP API.  This will
# cause the documentation to be collected into the HTTP API section of
# the Developer Guide.
#
# Comments should be written in markdown.
#
# The following directives are understood:
#
# * :api-url: - the URL of the API endpoint, relative to Errata Tool's
#               base path.  Specify multiple times if there are
#               alternative URLs, in which case the primary URL should
#               come first.
#
# * :api-method: - the HTTP method used with this API.
#
# * :api-category: - category name, used to group APIs in the
#                    documentation.
#
# * :api-request-example: - embed a 1 line example request or an external file.
#
# * :api-response-example: - embed a 1 line example response or an external file.
#
# :api-request-example: or :api-response-example: may refer to a file
# using the following syntax:
#
#  file:relative/path/to/file.json
#
# When loading the file, leading lines beginning with # will be
# stripped, for compatibility with baseline data under test/data.
#
# Directives placed on a class are inherited to methods.  This
# probably makes sense only for :api-category:.
#
class RDoc::Generator::ErrataApi
  SINGLE_DIRECTIVES = [
    :method,
    :category,
  ]
  MULTI_DIRECTIVES = [
    :url,
    :'request-example',
    :'response-example',
  ]
  DIRECTIVES = SINGLE_DIRECTIVES + MULTI_DIRECTIVES

  def initialize(options)
  end

  def generate(toplevels)
    all_apis = self.class.parse_code_objects(toplevels)

    self.class.sort_api(all_apis).each do |api|
      self.class.write_markdown_file(all_apis, api)
    end

    self.class.write_index_file(all_apis)
  end

  # Returns paths relative to the output directory.  rdoc is expected
  # to chdir to the output directory before calling the generator.
  def self.out_file(api)
    "#{api[:category].gsub(/\s/, '_')}.md"
  end

  def self.parse_code_objects(objects)
    out = []
    objects.each do |object|
      parse_comment(object, {}, out)
    end
    out
  end

  def self.sort_api(apis)
    apis.sort_by do |x|
      primary_url = x[:url].first

      # this is to get reasonable sorting of APIs like:
      #
      #  /add_build
      #  /remove_build
      #  /add_builds
      #  /reload_builds
      #
      # Since these are clearly related, it's nice to automatically
      # sort them next to each other.  Do that by flipping around the
      # last part so it becomes:
      #
      #  /build_add
      #  /build_remove
      #  /builds_add
      #  /builds_reload
      #
      # etc...
      munged_url = primary_url.gsub(%r{/([^/]+)$}, '/')
      munged_url += $1.split('_').reverse.join('_')

      [
        x[:category],
        munged_url,
        primary_url,
        x[:method]
      ]
    end
  end

  def self.write_markdown_file(all_apis, api)
    filename = out_file(api)
    File.open(filename, 'a') do |f|
      write_markdown(f, all_apis, api)
    end
  end

  def self.write_markdown(io, all_apis, api)
    all_urls = all_apis.map{|x| x[:url]}.flatten

    (primary_url,*other_urls) = api[:url]
    summary = api[:summary]
    name = "#{api[:method]} #{primary_url}"
    href = href_for(api[:method], primary_url)

    io.write("#### #{name}\n\n")

    # Every method/URL gets a link reference defined, so that methods
    # can easily link to each other.
    io.write("[#{name}]: #{href}\n\n")

    # Every unique URL also gets a link reference, so you don't have
    # to include the method if it's unambiguous without it.
    api[:url].select{|url| all_urls.grep(url).length == 1}.each do |url|
      io.write("[#{url}]: #{href}\n\n")
    end

    io.write("#{summary}\n\n")

    other_urls.each do |url|
      io.write("Alternative URL: `#{url}`\n\n")
    end

    %w[request response].each do |example_type|
      write_example(io, example_type, api)
    end

    unless api[:comment].blank?
      io.write(api[:comment])
      io.write("\n\n")
    end
  end

  def self.read_example_file(name)
    # Is there a better way to find the top-level checkout than this?
    path = File.expand_path(name, File.dirname(__FILE__) + "/../../..")
    content = File.read(path)
    lines = content.lines
    remove_lines = lines.take_while{|x| x =~ /^\s*#/}.length
    lines.to_a[remove_lines..-1].join.chomp
  end

  def self.write_example(io, type, api)
    examples = api[:"#{type}-example"] || []
    examples.each do |ex|
      if ex =~ %r{^file:(.+)$}
        io.write("Example #{type} body:\n\n```` JavaScript\n#{read_example_file($1)}\n````\n\n")
      else
        io.write("Example #{type} body:\\\n`#{ex}`\n\n")
      end
    end
  end

  def self.href_for(method, url)
    # FIXME: I think this is replicating pandoc or publican internal
    # logic.  Any better way?  This isn't _too_ awful, as at least the
    # doc generation fails if we generate the link wrongly.
    "\#api-#{method}-#{url.gsub(%r{[^a-zA-Z0-9_\.]}, '')}".downcase
  end

  # Returns a summary made brief (newlines stripped, trailing . stripped)
  def self.short_summary(summary)
    summary.gsub("\n", ' ').gsub(%r{(\.| )+$}, '')
  end

  # writes index to +io+ sort by url and method of +apis+
  def self.write_index(io, apis)
    table_rows = apis.sort_by { |x| [x[:url].first, x[:method]] }.map do |api|
      url = api[:url].first
      method = api[:method]
      summary = short_summary(api[:summary])

      link_target = href_for(method, url)

      [
        "[`#{url}`](#{link_target})",
        "#{method}",
        summary
      ]
    end

    longest_url = (['URL'] + table_rows.map(&:first)).map(&:length).max
    longest_method = (['Method'] + table_rows.map(&:second)).map(&:length).max
    longest_summary = (['Summary'] + table_rows.map{|tr| tr[2]}).map(&:length).max

    max_col = [longest_url, longest_method, longest_summary].max

    # Lame heuristics to make the table look a bit better...
    #
    # The only way I can find to pass width info from markdown through
    # to docbook is to use multiline tables, which looks at the
    # relative width of each column in the markdown.  So set the
    # desired relative widths first and then generate the markdown
    # accordingly.  multiline_tables are described at
    # http://johnmacfarlane.net/pandoc/README.html#tables .
    #
    # Method column is obviously the smallest.
    #
    # Let summary column be smaller than URL, since the text in
    # Summary (a sentence) wraps better than the text in URL (a single
    # string).
    #
    # Otherwise, just play with the numbers until it looks OK.
    #
    longest_url = max_col*6
    longest_method = max_col
    longest_summary = max_col*4

    longest_line = longest_url + longest_method + longest_summary + 2

    io.printf("%s\n", '-'*longest_line)
    io.printf("%-#{longest_url}s %-#{longest_method}s %-#{longest_summary}s\n", 'URL', 'Method', 'Summary')
    io.printf("%s %s %s\n", '-'*longest_url, '-'*longest_method, '-'*longest_summary)
    table_rows.each do |(url,method,summary)|
      io.printf("%-#{longest_url}s %-#{longest_method}s %-#{longest_summary}s\n\n", url, method, summary)
    end
    io.printf("%s\n\n", '-'*longest_line)
  end

  def self.write_index_file(apis)
    File.open("_index.md", "w") do |f|
      self.write_index(f, apis)
    end
  end

  def self.check_directives(context, d)
    if d[:url] && !d[:method]
      raise ArgumentError, "#{context.file}:#{context.line}: missing mandatory :api-method: directive"
    end
  end

  def self.parse_comment(context, inherited_directives = {}, into = [])
    (directives, comment) = self.extract_directives(context)
    directives = inherited_directives.merge(directives)

    self.check_directives(context, directives)

    if directives.include?(:url)
      directives[:category] ||= 'Other APIs'
      into << directives.merge(
        :context => context,
        :comment => comment)
    end

    children = []
    [:method_list, :classes_or_modules].each do |m|
      children.concat(context.send(m)) if context.respond_to?(m)
    end
    children.each do |method_ctx|
      self.parse_comment(method_ctx, directives, into)
    end
  end

  def self.trim_blank_lines(lines)
    leading_blank = lines.take_while(&:blank?).length
    lines = lines[leading_blank..-1]

    trailing_blank = lines.reverse.take_while(&:blank?).length
    lines = lines[0..-(1+trailing_blank)]

    lines
  end

  def self.extract_directives(context)
    raise_error = lambda{|error|
      raise ArgumentError, "#{context.file}:#{context.line}: #{error}"
    }

    out = {}
    comment = context.comment.is_a?(RDoc::Comment) ? context.comment.text : context.comment

    lines_without_directives = comment.lines.reject do |line|
      if line =~ %r{^\s*:api-([^:]+):\s+(.+?)\s*$}
        sym = $1.to_sym
        if !DIRECTIVES.include?(sym)
          raise_error.call("unknown directive :api-#{$1}:")
        end

        if MULTI_DIRECTIVES.include?(sym)
          out[sym] ||= []
          out[sym] << $2
        elsif out.include?(sym)
          raise_error.call("only a single value can be provided for :api-#{$1}:")
        else
          out[sym] = $2
        end
        true
      end
    end

    lines_without_directives = trim_blank_lines(lines_without_directives)

    # The first paragraph should be a brief summary.
    firstpart = true
    (summary, rest) = lines_without_directives.partition do |line|
      if line.blank?
        firstpart = false
      end
      firstpart
    end

    out[:summary] = summary.join.chomp

    [out, trim_blank_lines(rest).join.chomp]
  end

  RDoc::RDoc.add_generator self
end
