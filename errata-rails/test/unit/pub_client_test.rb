require 'test_helper'

class PubClientTest < ActiveSupport::TestCase
  setup do
    @client = Push::PubClient.new
    # Mock out all the XML-RPC endpoints so we don't attempt real requests
    @client_proxy = mock()
    @errata_proxy = mock()
    @auth_proxy = mock()
    @client.instance_variable_set('@client_proxy', @client_proxy)
    @client.instance_variable_set('@errata_proxy', @errata_proxy)
    @client.instance_variable_set('@auth_proxy', @auth_proxy)

    # These methods are used around every other method invocation
    @auth_proxy.stubs(:login_password => true, :logout => true)
  end

  test 'submit_multipush_jobs submits with multiple advisory names' do
    @errata_proxy.
      expects(:push_advisory).
      with('webdev',
           %w[RHSA-2010:0837 RHSA-2011:0212 RHSA-2011:0334],
           'vdanen@redhat.com',
           {'push_files' => true, 'priority' => 25, 'push_metadata' => true})

    @client.submit_multipush_jobs(valid_multipush_jobs)
  end

  test 'submit_multipush_jobs complains on target mismatch' do
    jobs = valid_multipush_jobs + [AltsrcPushJob.first]

    assert_multipush_problem('target') do
      @client.submit_multipush_jobs(jobs)
    end
  end

  test 'submit_multipush_jobs complains on username mismatch' do
    jobs = valid_multipush_jobs
    jobs[0].pushed_by = releng_user

    assert_multipush_problem('push_user_name') do
      @client.submit_multipush_jobs(jobs)
    end
  end

  test 'submit_multipush_jobs complains on options mismatch' do
    jobs = valid_multipush_jobs
    jobs[0].pub_options['foo'] = 'bar'

    assert_multipush_problem('pub_options') do
      @client.submit_multipush_jobs(jobs)
    end
  end

  test 'submit_multipush_jobs allows different priorities and uses highest' do
    jobs = valid_multipush_jobs
    jobs[0].pub_options['priority'] = 90

    @errata_proxy.
      expects(:push_advisory).
      with('webdev',
           %w[RHSA-2010:0837 RHSA-2011:0212 RHSA-2011:0334],
           'vdanen@redhat.com',
           {'push_files' => true, 'priority' => 90, 'push_metadata' => true})

    @client.submit_multipush_jobs(jobs)
  end

  test 'supports_multipush false if missing from capabilities' do
    @errata_proxy.expects(:capabilities).returns(%w[foo bar])
    refute @client.supports_multipush?
  end

  test 'supports_multipush true if present in capabilities' do
    @errata_proxy.expects(:capabilities).returns(%w[foo multipush bar])
    assert @client.supports_multipush?
  end

  test 'capabilities copes with missing method' do
    error = XMLRPC::FaultException.new(
      1, "Exception: method 'errata.capabilities' is not supported")
    @errata_proxy.expects(:capabilities).raises(error)

    # If using a version of pub prior to addition of this method, we assume an
    # empty set of capabilities
    assert_equal [], @client.capabilities
  end

  test 'capabilities passes through other kinds of errors' do
    error = XMLRPC::FaultException.new(
      1, 'simulated error')
    @errata_proxy.expects(:capabilities).raises(error)

    actual_error = assert_raises(XMLRPC::FaultException) do
      @client.capabilities
    end
    assert_equal error, actual_error
  end

  def assert_multipush_problem(field)
    error = assert_raises(RuntimeError) do
      yield
    end
    message = error.message
    assert_match 'Cannot use multipush!', message
    assert_match "#{field} mismatch on submitted jobs", message
  end

  def valid_multipush_jobs
    # These jobs have been located having the same pushed_by and options, which
    # is mandatory for multipush
    RhnLivePushJob.where(:id => [9145, 10485, 10921])
  end
end
