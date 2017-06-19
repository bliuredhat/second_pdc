require 'test_helper'

require 'rdoc/rdoc'
require 'rdoc/generator/errata_api'
require 'rdoc/parser/ruby'
require 'stringio'

class RDocErrataApiTest < ActiveSupport::TestCase
  test 'typical' do
    markdown_test('FakeApi#post_something', 'api/markdown/basic1.md')
    markdown_test('FakeApi#get_something', 'api/markdown/basic2.md')
  end

  test 'mixed examples' do
    markdown_test('FakeApi#examples', 'api/markdown/examples.md')
  end

  test 'inherited directives' do
    markdown_test('FakeApi::InheritedDirectives#api1', 'api/markdown/inherit1.md')
    markdown_test('FakeApi::InheritedDirectives#api2', 'api/markdown/inherit2.md')
  end

  test 'api-category is used to set filename' do
    [
      ['FakeApi#get_something', 'Test_Stuff.md'],
      ['FakeApi::InheritedDirectives#api1', 'Other.md'],
    ].each do |element, expected_file|
      assert_equal(
        expected_file,
        RDoc::Generator::ErrataApi.out_file(find_api(element)))
    end
  end

  test 'index' do
    io = StringIO.new
    RDoc::Generator::ErrataApi.write_index(io, fake_apis)
    assert_testdata_equal 'api/markdown/index.md', io.string
  end

  def find_api(element_name)
    fake_apis.find{|x| x[:context].full_name == element_name}
  end

  def markdown_test(element_name, baseline_file)
    apis = fake_apis
    this_api = find_api(element_name)
    assert_not_nil this_api, "unable to find API doc for element #{element_name}"

    io = StringIO.new
    RDoc::Generator::ErrataApi.write_markdown(io, apis, this_api)

    # this is a bit of a kludge...
    # assert_testdata_equal uses leading ## to mean something,
    # but that's also meaningful in markdown :(
    # Just prepend a blank line so the string can't start with ##.
    generated = "\n" + io.string

    assert_testdata_equal baseline_file, generated
  end

  def rdoc_parse_file(filename)
    top_level = RDoc::TopLevel.new(filename)
    content = File.read(filename)

    options = stub('options', :rdoc_include => nil, :encoding => nil, :markup => nil)
    stats = stub('stats', :add_class => nil, :add_method => nil, :add_module => nil)
    parser = RDoc::Parser::Ruby.new(top_level, __FILE__, content, options, stats)
    parser.scan
    top_level
  end

  def fake_apis
    @@_parsed ||= RDoc::Generator::ErrataApi.parse_code_objects(
      [rdoc_parse_file(__FILE__)]
    )
  end
end

# :api-category: Test Stuff
module FakeApi

  # Does something great, but I'm not gonna tell you what it is.
  #
  # :api-url: /fake/something
  # :api-method: POST
  # :api-request-example: {"typical":"request"}
  # :api-response-example: {"whatever":"response"}
  #
  # There's some more details about it here.
  #
  def post_something; end

  # Fetches something great, but I'm not gonna tell you what it is.
  #
  # :api-url: /fake/something
  # :api-method: GET
  #
  # The fact that this API uses a different method but the same URL as
  # another API influences linking behavior.
  #
  def get_something; end

  # This doc mixes up inline examples with examples from files, and
  # also has a summary which is written over more than one line.
  #
  # :api-url: /good/examples
  # :api-method: GET
  # :api-request-example: inline example
  # :api-request-example: file:test/data/api/sample1.json
  # :api-response-example: file:test/data/api/sample2.json
  # :api-response-example: inline example
  #
  # This text should appear after all the examples.
  def examples; end

  # This class declares a method and category which should be
  # inherited to the methods belonging to it.
  #
  # :api-method: PATCH
  # :api-category: Other
  class InheritedDirectives
    # Does something.
    #
    # :api-url: /api1
    def api1; end

    # Does other thing.
    #
    # :api-url: /api2
    def api2; end
  end
end
