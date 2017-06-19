ENV["RAILS_ENV"] = "test"
require 'simplecov' if ENV['COVERAGE']

require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'rails/test_help'
require "test/unit"
require "mocha/test_unit"

require 'parallel_tests/test/runtime_logger' if ENV['RECORD_RUNTIME']
require 'ci/reporter/rake/test_unit_loader'  if ENV['CI_REPORTS']

require 'capybara'
require 'capybara/rails'

require 'nokogiri'

require 'test_helper/data'
require 'test_helper/logging'
require 'test_helper/json'
require 'test_helper/with_stubbed_const'
require 'test_helper/with_stubbed_class_variable'
require 'test_helper/dist_qa_tps_test_helper'

require 'test_helper/webmock'
require 'test_helper/vcr'

require 'diffstring'

#------------------------------------------------------------------------
class ActionDispatch::IntegrationTest
  include Capybara::DSL

  teardown do
    # Each test should start unauthenticated
    logout
  end

  # Make the simple get, post, put methods include the same headers
  # used by the page driver.  This allows auth_as/logout to work also
  # for these methods.
  [:get, :post, :put].each do |method|
    define_method(method) do |*args|
      path       = args[0]
      parameters = args[1] || nil
      env        = args[2] || nil

      new_env = (page.driver.browser.options[:headers] || {}).dup
      if env
        new_env.merge!(env)
      end

      # Let the new arguments go via method_missing, as normal.
      self.method_missing(method, path, parameters, new_env)
    end
  end

  # Requests to the specified URL with a JSON request body.
  #
  # This method is provided so that tests can fully cover the parsing
  # of a JSON request body into parameters.  When using the typical
  # method of passing a parameters hash to post, that hash is directly
  # merged into the `params' object accessible from controllers.  That
  # means the test is at risk of being inaccurate if the test
  # developer didn't set the parameters in the same way they'd be set
  # in production.
  #
  # Use this method when you really want to test that the request body
  # is being parsed into parameters correctly.
  #
  def request_with_json(method, url, json)
    unless json.kind_of?(String)
      json = json.to_json
    end

    # peeked at the rack implementation to figure out the necessary
    # keys here.
    self.send(method, url, nil,
      'CONTENT_TYPE' => 'application/json',
      'CONTENT_LENGTH' => json.length,
      'rack.input' => StringIO.new(json))
  end

  def post_json(url, json)
    request_with_json :post, url, json
  end

  def put_json(url, json)
    request_with_json :put, url, json
  end
end

module Capybara::DSL
  #
  # In production we use kerberos for auth which requires configuration via
  # apache. In our test environment setting the HTTP_X_REMOTE_USER like this
  # seems to be enough to simulate an authed user.
  #
  def auth_as(user)
    # So we can take either a string or a User object
    user = user.login_name if user.is_a? User
    case Capybara.current_driver
    when :rack_test
      page.driver.browser.options[:headers] ||= {}
      page.driver.browser.options[:headers]['HTTP_X_REMOTE_USER'] = user
    when :poltergeist
      Capybara.current_session.driver.add_headers('X_REMOTE_USER' => user)
    end
  end

  def logout
    page.driver.browser.options[:headers] = {}
  end
end

#------------------------------------------------------------------------
class ActiveSupport::TestCase
  include TestData
  include WithStubbedConst
  include WithStubbedClassVariable
  include DistQaTpsTestHelper

  # This is defined in MiniTest which is standard with ruby
  # 1.9, so when/if we update, might be able to remove this.
  def refute(condition, message='')
    assert(!condition, message)
  end

  def assert_array_equal(expected, actual, msg = nil)
    msg = msg + "\n" unless msg.nil?
    assert_equal expected.length, actual.length, "#{msg}Arrays not of equal length! #{expected.length} vs #{actual.length}"
    expected = expected.sort
    actual = actual.sort

    expected.each_with_index do |e, i|
      assert_equal e, actual[i], "#{msg}Element mismatch position #{i}: #{e} vs #{actual[i]}"
    end
  end

  def assert_equal_or_diff(expected, actual, msg = 'Expected and actual value differ')
    diff = ''
    if expected != actual
      diff = diff_as_string expected, actual
    end
    # diff_as_string doesn't return anything if the only difference is leading/trailing whitespace.
    # Make that case show something as well
    if diff.blank?
      assert_equal expected, actual, msg
    else
      assert expected == actual, "#{msg}\n--- expected\n+++ actual\n#{diff}"
    end
  end

  def assert_errors_include(ar, msg)
    assert ar.errors.full_messages.include?(msg), "Old Errors: #{errors_to_string(ar)}\nNew Errors: #{msg}"
  end

  # When running just one test you probably don't want to reload fixtures
  # since it takes a really long time and they are usually already loaded anyway.
  # Skip fixture loading by setting NO_FIXTURE_LOAD, eg:
  #  NO_FIXTURE_LOAD=1 ruby -Ilib:test test/unit/text_with_impact_link_test.rb
  fixtures(:all) unless ENV['NO_FIXTURE_LOAD']

  set_fixture_class :errata_arches => 'Arch'
  set_fixture_class :errata_versions => 'Variant'
  set_fixture_class :errata_products => 'Product'

  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Add more helper methods to be used by all tests here...
  setup :setup_rpmdiff
  setup :setup_messagebus_handler
  setup :stub_pdc_token

  teardown do
    Thread.current[:current_user] = nil
  end

  def assert_state_failure(errata, state, msg, user = qa_user)
    ex = assert_raise(ActiveRecord::RecordInvalid) {errata.change_state!(state, user)}
    assert_equal msg, ex.message
  end

  def assert_valid(ar)
    assert ar.valid?, errors_to_string(ar)
  end

  def errors_to_string(active_record_object)
    active_record_object.errors.full_messages.join(', ')
  end

  def mock_errata_product_listing(errata)
    # This mock function to create a fake product listing from brew, because
    # most of the test advisories in the fixture don't have proper cached
    # product listing. Without proper brew build and brew rpm in the advisory
    # will sometimes cause the test to fail. In bug 1085498, I added a feature
    # that allow users to control target to be pushed in the variant and package
    # level. Which means a cdn and rhn supported advisory may possibly end up
    # pushing rpm files to cdn/rhn only.
    data = []
    errata.errata_brew_mappings.each do |map|
      variant = map.product_version.variants.first
      brew_rpms = BrewRpm.limit(3)
      arch_list = brew_rpms.map{ |rpm| rpm.arch }
      brew_rpms.each do |rpm|
        data << [rpm, variant, map.brew_build, arch_list]
      end
    end
    ErrataBrewMapping.any_instance.stubs(:build_product_listing_iterator).multiple_yields(*data)
  end

  # create a new version of brew build by given the old product listing
  def create_test_brew_build(old_product_listing_id, new_rpm_version, new_rpm_release, new_product_version_name)
    new_product_version = ProductVersion.find_by_name!(new_product_version_name)
    old_product_listing = ProductListingCache.find(old_product_listing_id)

    old_build = old_product_listing.brew_build
    p = old_build.package
    n = p.name
    v = new_rpm_version
    r = new_rpm_release
    new_build = BrewBuild.create!(
      :package => p, :version => v, :release => r, :nvr => [n,v,r].join("-"))
    new_build.reload

    old_build.brew_rpms.each do |rpm|
      attrs = rpm.attributes.\
        reject{|col,val| col == "id"}.\
        merge!({:name => [rpm.name_nonvr,v,r].join("-"), :brew_build_id => new_build.id, :is_signed => 0, :id_brew => BrewRpm.pluck('max(id_brew)').first + 100})
      BrewRpm.create!(attrs)
    end

    cache = YAML.load(old_product_listing.cache).each_with_object({}) do |(variant, all_files), h|
      file_arch_maps = all_files.each_with_object({}) do |(file, arches), maps|
        filename = file.sub(/([^-]+)-([^-]+)$/, [v,r].join("-"))
        maps[filename] = arches
      end
      h[variant] = file_arch_maps
    end

    ProductListingCache.create!(
      :product_version => new_product_version,
      :brew_build => new_build,
      :cache => cache.to_yaml)

    return new_build.reload
  end

  def ship_test_errata_packages(errata)
    errata.stubs(:status).returns(State::SHIPPED_LIVE)
    ReleasedPackage.make_released_packages_for_errata(errata)
  end

  def setup_rpmdiff
    # fixup for a problem with rpmdiff fixtures.
    # We need RpmdiffScore::PASSED to have an ID of 0.
    # Loading it directly from fixtures with ID of 0 doesn't work (see comment in fixture yml),
    # so we have to fix it up here.
    RpmdiffScore.connection.exec_update('UPDATE rpmdiff_scores SET id=0 WHERE score=0', nil, nil)
  end

  def stub_pdc_token
    stub_request(:any, "#{PdcConf::SITE}/rest_api/v1/auth/token/obtain/")
      .to_return(body: { token: '<TOKEN>' }.to_json)
  end

  def setup_messagebus_handler
    MessageBus::Handler.any_instance.stubs(:topic_send).returns()
  end

  def with_current_user(user, &block)
    olduser = Thread.current[:current_user]
    begin
      Thread.current[:current_user] = user
      yield
    ensure
      Thread.current[:current_user] = olduser
    end
  end

  def assign_user_to_org_group(user, group)
    group = UserOrganization.find_by_name('Kernel Filesystem') unless group.is_a?(UserOrganization)
    user.update_attribute('organization', group)
  end

  def assign_user_to_kernel_group(user)
    assign_user_to_org_group(user, 'Kernel Filesystem')
  end

  # Executes a block while modifying the behavior of Delayed::Job.enqueue.
  # All jobs whose class matches the given pattern will be performed before
  # force_sync_delayed_jobs returns.
  # All other jobs will be ignored.
  # This allows temporarily treating delayed jobs as synchronous to allow for
  # more concise tests.
  # Returns the value evaluated by the block.
  def force_sync_delayed_jobs(pattern=//, &block)
    jobs = []
    out = _capture_delayed_jobs(pattern, jobs, &block)
    jobs.each(&:perform)
    out
  end

  # Executes a block while modifying the behavior of Delayed::Job.enqueue.
  # All jobs whose class matches the given pattern will be captured into an array
  # when enqueued.  The array of jobs is returned.
  # All other jobs will be ignored.
  def capture_delayed_jobs(pattern=//, &block)
    jobs = []
    _capture_delayed_jobs(pattern, jobs, &block)
    jobs
  end

  def _capture_delayed_jobs(pattern, jobs, &block)
    ActiveSupport::TestCase.with_replaced_method(Delayed::Job, :enqueue, lambda do |job,*args|
      jobs << job if pattern === job.class.to_s
      Delayed::Job.new
    end, &block)
  end

  # Executes a block while replacing a method on one or more objects or classes.
  #
  # obj may be a single instance/class or an array of instances/classes.
  #
  # For classes, a class method is replaced.
  # Otherwise, an instance method on the specific object is replaced.
  def self.with_replaced_method(obj, method_name, method_proc, &block)
    unless obj.respond_to?(:each_with_index)
      obj = [obj]
    end
    mclass = []
    old_meth = []

    obj.each_with_index do |o,i|
      mclass[i] = (class << o; self; end)
      old_meth[i] =
        begin
          o.method(method_name)
        rescue NameError
          # It's OK if method doesn't exist
        end
    end

    begin
      mclass.each do |klass|
        klass.send(:define_method, method_name, method_proc)
      end
      yield
    ensure
      mclass.each_with_index do |klass,i|
        old = old_meth[i]
        if old
          klass.send(:define_method, method_name, old)
        else
          klass.send(:remove_method, method_name)
        end
      end
    end
  end

  # Returns path to the top-level directory used for test data files.
  def datadir
    "#{Rails.root}/test/data"
  end

  # Run a block, comparing its output against a set of baselines.
  #
  # +path+ must be a directory under test/data.  For each file in that directory,
  # +pattern+ is evaluated.  If it matches the filename, the given block is executed.
  # The block is given the MatchData for the filename pattern match.
  #
  # The value returned by the block is compared against the baseline file.
  # If it differs, the test fails with a unified diff between the expected and actual values.
  #
  # If the environment variable ET_UPDATE_BASELINE is set to 1, the test will update the
  # baseline files rather than failing the test.
  #
  # Example:
  #
  #   with_baselines('errata_reports', /errata-(\d+)\.txt$/) do |match|
  #     report_controller.get_report(:errata => Errata.find(match[1].to_i))
  #   end
  #
  def with_baselines(path, pattern, options={}, &block)
    count = 0
    errors = []
    Dir.glob("#{datadir}/#{path}/*").each do |filename|
      next unless filename =~ pattern
      count += 1
      output = yield(*($LAST_MATCH_INFO.to_a))
      begin
        assert_testdata_equal(filename, output, options)
      rescue Test::Unit::AssertionFailedError => ex
        errors << ex
      end
    end
    assert count > 0, "no test data files found in #{datadir} - check the test environment"

    flunk errors.map(&:message).join("\n\n") if errors.present?
  end

  def with_xml_baselines(path, pattern, options = {}, &block)
    with_baselines(path, pattern, {
      :canonicalize => lambda { |data| Nokogiri::XML::Document.parse(data).canonicalize }
    }.merge(options), &block)
  end

  # Compare the expected data in the file given by +filename+ with the specified +actual_data+.
  #
  # If +filename+ is relative, it is resolved under the top-level
  # testdata directory.
  #
  # If it differs, the test fails.  The failure message includes a unified diff.
  #
  # If the environment variable ET_UPDATE_BASELINE is set to 1, the file is updated rather
  # than failing the test.
  #
  # The file may start with a block of lines beginning with '###'.  These lines are
  # considered to be comments, and will be retained over baseline updates.
  def assert_testdata_equal(filename, actual_data, options = {})
    filename = "#{datadir}/#{filename}" if Pathname.new(filename).relative?

    if File.exist?(filename)
      expected_data = IO.read(filename)

      lines = expected_data.lines

      comments = lines.take_while { |x| x =~ /^###/ }
      expected_data = lines.drop(comments.length).join
      comments = comments.join
    end

    if options[:canonicalize]
      actual_data = options[:canonicalize].call(actual_data)
    end

    with_newline = lambda do |str|
      if str.blank? || str.ends_with?("\n")
        str
      else
        str + "\n"
      end
    end
    expected_data = with_newline.call(expected_data)
    actual_data = with_newline.call(actual_data)

    do_write = lambda do |file|
      file.write(comments) unless comments.blank?
      file.write(actual_data)
      file.flush
    end

    begin
      assert_equal expected_data, actual_data
    rescue Test::Unit::AssertionFailedError => ex
      if ENV['ET_UPDATE_BASELINE'] == '1'
        File.open(filename, 'w') do |expected_file|
          do_write.call(expected_file)
          puts "Updated #{filename}"
        end
      else
        # show the output via diff
        with_tempfile('errata-test-') do |actual_file|
          do_write.call(actual_file)

          diff_filename = File.exist?(filename) ? filename : '/dev/null'

          diff = `diff --label '#{diff_filename}' --label 'test output' -du '#{diff_filename}' '#{actual_file.path}'`
          assert_equal 1, $CHILD_STATUS.exitstatus, "assert_equal fails but diff claims #{filename} is equal to:\n#{actual_data}"
          raise ex.class, "Test output differs from expected.\nRun with ET_UPDATE_BASELINE=1 to update the data.\n#{diff}"
        end
      end
    end
  end

  def with_tempfile(prefix)
    tempfile = Tempfile.new(prefix)
    begin
      yield tempfile
    ensure
      tempfile.close!
    end
  end


  # Execute a block, adding additional detail to the failure assertion if
  # a failure occurs.
  #
  # +block+ is executed.  If it raises an exception, +msg+ is appended to the
  # exception's message before propagating it.
  #
  # If +msg+ is a Proc, it is invoked to generate the message.
  def with_failure_message(msg, &block)
    begin
      yield
    rescue Exception => ex
      suffix = msg.kind_of?(Proc) ? msg.call() : msg.to_s
      newex = ex.class.new(ex.message + "\n#{suffix}")
      newex.set_backtrace(ex.backtrace)
      raise newex
    end
  end

  # Execute a series of blocks, simulating a couple of seconds
  # time passing between each block.
  # Warning: Time.now remains stubbed after this method returns.
  def with_time_passing(*blocks)
    time = Time.now

    blocks.each do |block|
      Time.stubs(:now => time)
      block.call
      time += 2.seconds
    end
  end

  def assert_active_errata_table(errata, title, note = nil)
    limit = 20
    total = errata.count
    if total <= 0
      assert_equal title, find(:xpath, %{//div[@id="noresult_div"]/label}).text
    else
      root_path = %Q{//div[@id="advisory_list_div"]}
      content_path = root_path + %Q{/div[@id="advisory_content_div"]}
      total_text = total < limit ? total : "Showing #{limit} out of #{total}"

      within(:xpath, root_path) do
        # ensure the title is showing correctly
        expected_title = "#{title} (#{total_text}):"
        assert_equal expected_title, find(:xpath, "./label").text
        # ensure the NOTE is printed
        assert_equal note, find(:xpath, "./div/label").text if note
      end

      # check the table contents
      within(:xpath, content_path) do
        # ensure no more than 20 rows are shown
        assert has_xpath?("(./table/tbody/tr)", :count => total < limit ? total : limit)

        # ensure the content in each row is correct
        errata.each.sort_by(&:id).take(limit).each.with_index do |et, index|
          index = index + 1
          row_text = find(:xpath, "(./table/tbody/tr)[#{index}]").text
          assert_equal "#{et.advisory_name} #{et.release.name} #{et.status} #{et.synopsis}", row_text
        end
      end
    end
  end

  def run_all_delayed_jobs
    Time.stubs(:now => 1.hour.from_now)
    Delayed::Job.count.times do
      Delayed::Job.reserve_and_run_one_job
    end
  end

  def create_push_job(errata, klass, user = User.system)
    j = klass.new(:errata => errata, :pushed_by => user)
    assert j.valid?, "created job for #{klass} is not valid: #{j.errors.full_messages.join(', ')}"
    j.set_defaults
    j.save!

    pc = Push::PubClient.get_connection
    assert_equal Push::DummyClient, pc.class
    j.create_pub_task(pc)
    assert_equal 'WAITING_ON_PUB', j.status, "Job status is not 'WAITING_ON_PUB'"
    j
  end

  def formatted_mail(mail)
    return '<no mail>' if mail.blank?
    exclude = %w[Date From Message-ID Mime-Version
            Content-Type Content-Transfer-Encoding]
    header = mail.header
    lines = header.fields.
            reject{ |f| exclude.include?(f.name) }.
            map{ |f| "#{f.name}: #{Array.wrap(f.value).join(', ')}" }
    lines << ''
    lines << mail.body.to_s
    lines.join("\n")
  end

  # Stubs Time.now to always return a specific, arbitrary value.
  # Use this to make logs and other time-sensitive results stable in tests.
  def fix_time
    Time.stubs(:now => Time.at(1439200000))
  end
end

class ActionController::TestCase

  def auth_as(user)
    user = User.find_by_name(user) unless user.is_a? User
    @request.env['HTTP_X_REMOTE_USER'] = user.login_name
  end

end

module FakeJiraRpc
  extend ActiveSupport::Concern

  included do
    setup do
      FakeWeb.allow_net_connect = false
      # assemble the URL to be used by fakeweb
      url = URI.parse(Jira::JIRA_URL)
      url.user = Jira::JIRA_USER
      url.password = Jira::JIRA_PASSWORD
      @jira_url = url.to_s
    end

    teardown do
      FakeWeb.allow_net_connect = true
      FakeWeb.clean_registry()
    end

    def register_uri(method, uri_relative, options)
      FakeWeb.register_uri(method, "#{@jira_url}#{uri_relative}", options)
    end
  end
end

class MockLogger
  @@log = []

  def self.info(msg)
    @@log << msg
  end

  def self.debug(msg)
    @@log << msg
  end

  def self.warn(msg)
    @@log << msg
  end

  def self.error(msg)
    @@log << msg
  end

  def self.fatal(msg)
    @@log << msg
  end

  def self.log
    @@log
  end

  def self.reset
    @@log = []
  end

  def self.to_s
    @@log.join("\n")
  end
end

# Convert the model bug back to rpc bug object
# so that we can simulate the bug updates
class TestRpcBug < Bugzilla::Rpc::RPCBug
  def initialize(model_bug)
    # Superclass constructor must be called, or method_missing will crash
    super({})

    now = Time.now
    Time.stubs(:now).returns(now)

    model_bug.attributes.each_pair do |field, value|
      next if field =~ /^id|_id$/
      next if ['last_updated'].include?(field)
      self.class.send(:attr_accessor, field)
      self.send("#{field}=", value)
    end

    [:bug_id, :component].each do |field|
      self.class.send(:attr_accessor, field)
    end

    self.bug_id = model_bug.bug_id
    self.component = model_bug.package.name
    self.errata_package = model_bug.package

    klass = class << self; self; end
    [:is_private, :is_security, :is_blocker, :is_exception].each do |field|
      klass.send(:define_method, "#{field}?", lambda {self.send(field) == 1 ? true : false})
    end

    @changeddate = model_bug.last_updated
    klass.send(:define_method, "changeddate", lambda { @changeddate } )
  end
end
