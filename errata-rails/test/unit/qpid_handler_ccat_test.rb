require 'test_helper'

class QpidHandlerCcatTest < ActiveSupport::TestCase
  @@subscriptions = []

  setup do
    @@subscriptions.each do |name|
      send(name)
    end

    assert @message_handler, "Module did not subscribe!"

    @logs = []
  end

  test 'message missing ERRATA_ID' do
    inject_message('foo', {'bar' => 'baz'})
    assert_logged 'Error processing CCAT message "foo" {"bar"=>"baz"}'
    assert_logged %r{Couldn't find Errata}
  end

  test 'JOB_NAME is irrelevant and falls back to ccat' do
    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.test/8888'},
                     {'ERRATA_ID' => Errata.first.id.to_s,
                      'JOB_NAME'  => 'some-job',
                      'MESSAGE_TYPE' => 'running'})
    end
    run = ExternalTestRun.last
    assert_equal ExternalTestType.get(:ccat), run.external_test_type
    assert_nil run.pub_target
  end

  test 'JOB_NAME does not have to be specified' do
    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.test/8888'},
                     {'ERRATA_ID' => Errata.first.id.to_s,
                      'MESSAGE_TYPE' => 'running'})
    end
  end

  test 'ccat manual can be specifid as JOB_NAME ' do
    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.test/8888'},
                     {'ERRATA_ID' => Errata.first.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation_manual',
                      'MESSAGE_TYPE' => 'running'})
    end
    run = ExternalTestRun.last
    assert_equal ExternalTestType.get('ccat/manual'), run.external_test_type
    assert_nil run.pub_target
  end

  test 'message with bad BUILD_URL' do
    inject_message({'BUILD_URL' => 'http://example.com/foo/bar'},
                   {'ERRATA_ID' => Errata.first.id.to_s,
                    'JOB_NAME'  => 'cdn_content_validation'})
    assert_logged %r{Error processing CCAT message}
    assert_logged 'Could not calculate build number from http://example.com/foo/bar'
  end

  test 'message with ERRATA_ID mismatch' do
    run = ExternalTestRun.find(79)
    assert_equal 'ccat', run.name

    # If we get a message for this run, but a different errata than before, it's
    # an error
    inject_message({'BUILD_URL' => "http://example.com/foo/#{run.external_id}/"},
                   {'ERRATA_ID' => '2128',
                    'JOB_NAME'  => 'cdn_content_validation'})
    assert_logged %r{Error processing CCAT message}
    assert_logged "Test previously referred to RHSA-2014:2021-08 and now refers to RHBA-2005:324-08"
  end

  test 'message with bad MESSAGE_TYPE' do
    inject_message({'BUILD_URL' => 'http://example.com/foo/888888'},
                   {'ERRATA_ID' => Errata.first.id.to_s,
                    'JOB_NAME'  => 'cdn_content_validation',
                    'MESSAGE_TYPE' => 'something-weird'})
    assert_logged %r{Error processing CCAT message}
    assert_logged 'Unknown message type something-weird'
  end

  test 'started message for a run we already have' do
    run = ExternalTestRun.of_type('ccat').first
    inject_message({'BUILD_URL' => "http://example.com/foo/#{run.external_id}"},
                   {'ERRATA_ID' => run.errata_id.to_s,
                    'JOB_NAME'  => 'cdn_content_validation',
                    'TARGET'    => 'cdn-live',
                    'MESSAGE_TYPE' => 'running'})
    assert_logged %r{Error processing CCAT message}
    assert_logged "Got a 'test started' message for a run #{run.id} already existing"
  end

  test 'creates test run as expected' do
    errata = empty_ccat_errata

    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.com/123456'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'running'})
    end

    created = ExternalTestRun.last
    assert_equal errata, created.errata
    assert_equal 'PENDING', created.status
    assert_equal 123456, created.external_id
    assert created.active?
  end

  test 'runs are superseded' do
    errata = empty_ccat_errata

    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.com/123456'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'running'})
    end

    first_run = ExternalTestRun.last

    # Now simulate another run for the same errata.
    # (Note it's not required for a run to be finished before superseded)
    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.com/123457'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'running'})
    end

    first_run.reload
    second_run = ExternalTestRun.last

    assert_equal errata, first_run.errata
    assert_equal errata, second_run.errata

    assert_equal 'PENDING', first_run.status
    assert_equal 'PENDING', second_run.status

    assert_equal 123456, first_run.external_id
    assert_equal 123457, second_run.external_id

    refute first_run.active?
    assert second_run.active?

    assert_equal second_run, first_run.superseded_by
    assert_equal nil,        second_run.superseded_by
  end

  test 'ccat and ccat/manual supersede each other' do
    errata = empty_ccat_errata

    runs = []

    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.com/123456'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'running'})
    end

    runs << ExternalTestRun.last

    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.com/123457'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation_manual',
                      'MESSAGE_TYPE' => 'running'})
    end

    runs.each(&:reload)
    runs << ExternalTestRun.last

    # ccat/manual run superseded the ccat run
    assert_equal 'ccat',        runs[0].name
    assert_equal 'ccat/manual', runs[1].name

    refute runs[0].active?
    assert runs[1].active?

    assert_equal runs[1], runs[0].superseded_by
    assert_equal nil,     runs[1].superseded_by

    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.com/123458'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'running'})
    end

    runs.each(&:reload)
    runs << ExternalTestRun.last

    # ccat run superseded the ccat/manual run
    assert_equal 'ccat',        runs[0].name
    assert_equal 'ccat/manual', runs[1].name
    assert_equal 'ccat',        runs[2].name

    refute runs[0].active?
    refute runs[1].active?
    assert runs[2].active?

    assert_equal runs[1], runs[0].superseded_by
    assert_equal runs[2], runs[1].superseded_by
    assert_equal nil,     runs[2].superseded_by
  end

  test 'create and complete a run' do
    errata = empty_ccat_errata

    refute errata.external_test_runs_passed_for?('ccat')

    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.com/123456'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'running'})
    end

    refute errata.external_test_runs_passed_for?('ccat')

    run = ExternalTestRun.last
    assert_equal 'PENDING', run.status
    assert_equal 'PENDING', run.external_status

    assert_no_difference('ExternalTestRun.count') do
      inject_message({'BUILD_URL' => 'http://example.com/123456'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'pass'})
    end

    run.reload

    assert_equal 'PASSED', run.status
    assert_equal 'pass', run.external_status

    assert errata.external_test_runs_passed_for?('ccat')
  end

  # Bug 1299673
  test 'issue URL is stored' do
    errata = empty_ccat_errata

    assert_difference('ExternalTestRun.count', 1) do
      # It would be unusual to receive a jira issue id for a running event,
      # but we accept it anyway
      inject_message({'BUILD_URL' => 'http://example.com/123456'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'running',
                      'JIRA_ISSUE_ID' => 'ISSUE-12345'})
    end

    assert_equal 'https://projects.engineering.redhat.com/browse/ISSUE-12345', ExternalTestRun.last.external_message

    assert_no_difference('ExternalTestRun.count') do
      # This is more common - a failed result with a jira issue ID.
      inject_message({'BUILD_URL' => 'http://example.com/123456'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'fail',
                      'ERROR_CAUSE' => '["Problems","Other problems"]',
                      'JIRA_ISSUE_ID' => 'ISSUE-4567'})
    end

    assert_equal "Problems\nOther problems\nhttps://projects.engineering.redhat.com/browse/ISSUE-4567", ExternalTestRun.last.reload.external_message
  end

  test 'failed run manually retriggered' do
    # This tests a common scenario:
    # The test ran automatically and failed.
    # After fixing something, the test was manually retriggered and passes.
    errata = empty_ccat_errata

    refute errata.external_test_runs_passed_for?('ccat')

    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.com/123456'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'running'})
    end

    assert_no_difference('ExternalTestRun.count') do
      inject_message({'BUILD_URL' => 'http://example.com/123456'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'fail',
                      'ERROR_CAUSE' => '["Problems","Other problems"]'})
    end

    refute errata.external_test_runs_passed_for?('ccat')

    # Check the error cause came through OK
    assert_equal "Problems\nOther problems", ExternalTestRun.last.external_message

    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.com/123457'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation_manual',
                      'MESSAGE_TYPE' => 'running'})
    end

    assert_no_difference('ExternalTestRun.count') do
      inject_message({'BUILD_URL' => 'http://example.com/123457'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation_manual',
                      'MESSAGE_TYPE' => 'pass'})
    end

    assert errata.reload.external_test_runs_passed_for?('ccat')

    runs = errata.external_test_runs.order('id asc').to_a

    assert_equal %w[ccat ccat/manual], runs.map(&:name)
    assert_equal [false, true],        runs.map(&:active?)
  end

  test 'completing unknown run is OK with warning' do
    errata = empty_ccat_errata

    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.com/123456'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'pass'})
    end

    assert_logged 'Testing completed for previously unseen test run'

    created = ExternalTestRun.last
    assert_equal errata, created.errata
    assert_equal 'PASSED', created.status
    assert_equal 123456, created.external_id
    assert created.active?
  end

  test 'bogus ERROR_CAUSE is tolerated' do
    errata = empty_ccat_errata

    assert_difference('ExternalTestRun.count', 1) do
      inject_message({'BUILD_URL' => 'http://example.com/123456'},
                     {'ERRATA_ID' => errata.id.to_s,
                      'JOB_NAME'  => 'cdn_content_validation',
                      'MESSAGE_TYPE' => 'pass',
                      'ERROR_CAUSE' => 'milo => otis'})
    end

    assert_logged /Ignored CCAT ERROR_CAUSE.*unexpected token/

    created = ExternalTestRun.last
    assert_equal errata, created.errata
    assert_equal 'PASSED', created.status
    assert_equal 123456, created.external_id
    assert created.external_message.blank?
    assert created.active?
  end

  # Returns an errata which uses CCAT but currently has no results
  def empty_ccat_errata
    errata = Errata.find(20836)
    assert errata.requires_external_test?('ccat')
    refute errata.external_test_runs.any?
    errata
  end

  def inject_message(content, properties)
    msg = mock()
    msg.stubs(:getProperties => properties)

    logs = capture_logs do
      @message_handler.call(content, msg)
    end
    @logs.concat(logs)
  end

  def assert_logged(string_or_pattern)
    match = \
      if string_or_pattern.kind_of?(String)
        lambda do |message|
          message == string_or_pattern
        end
      else
        lambda do |message|
          message =~ string_or_pattern
        end
      end

    messages = @logs.map{ |l| l[:msg] }
    assert(
      messages.any?(&match),
      "Logs did not match: #{string_or_pattern}\nGot:\n#{messages.join("\n")}")
  end

  # These methods normally come from MessageBus::QpidHandler, where the module
  # is designed to be included.  Provide them here to capture the message
  # handling callback.
  def self.add_subscriptions(name)
    @@subscriptions << name
  end

  def topic_subscribe(exchange, topic, &block)
    if @message_handler
      flunk "expected exactly 1 subscription from the module under test"
    end
    @message_handler = block
  end

  include MessageBus::QpidHandler::Ccat
end
