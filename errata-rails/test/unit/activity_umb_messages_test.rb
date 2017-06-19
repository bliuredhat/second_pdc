require 'test_helper'

class ActivityUmbMessagesTest < ActiveSupport::TestCase

  test "creating new errata sends a message" do
    (topic, message, properties) = message_generated_by do
      errata = RHBA.create!(:reporter => qa_user,
                        :synopsis => 'test 1',
                        :product => Product.find_by_short_name('RHEL'),
                        :release => async_release,
                        :assigned_to => qa_user,
                        :content =>
                        Content.new(:topic => 'test',
                                    :description => 'test',
                                    :solution => 'fix it')
                        )
    end

    assert_equal 'errata.activity.created', topic
  end

  test "changing state creates a send message job with expected activity message" do
    errata = Errata.find(16409)
    Time.stubs(:now => Time.utc(2015,3,12))

    (topic, message, properties) = message_generated_by { errata.change_state!('NEW_FILES', devel_user) }

    assert_equal 'errata.activity.status', topic

    assert_equal({
      'from' => 'QE',
      'to' => 'NEW_FILES',
      'who' => 'qa-errata-list@redhat.com',
      'when' => '2015-03-12 00:00:00 UTC',
      'errata_id' => errata.id,
      'errata_status' => 'NEW_FILES',
      'synopsis' => errata.synopsis,
      'fulladvisory' => errata.fulladvisory,
    }, message)

    assert_equal({
      'subject' => 'errata.activity.status',
      'from' => 'QE',
      'to' => 'NEW_FILES',
      'who' => 'qa-errata-list@redhat.com',
      'when' => '2015-03-12 00:00:00 UTC',
      'errata_id' => errata.id,
      'errata_status' => 'NEW_FILES',
      'synopsis' => errata.synopsis,
      'fulladvisory' => errata.fulladvisory,
    }, properties)
  end

  test 'changing QE owner sends a message' do
    errata = Errata.find(20836)

    (topic, message, properties) = message_generated_by do
      errata.assigned_to = User.find_by_login_name!('kernel-qe@redhat.com')
      errata.save!
    end

    assert_equal 'errata.activity.assigned_to', topic

    assert_equal({
      'from' => 'qa-errata-list@redhat.com',
      'to' => 'kernel-qe@redhat.com',
    }, message.slice('from', 'to'))
  end

  test 'request the approval of docs sends a message' do
    errata = Errata.find(20836)
    (topic, message, properties) = message_generated_by do
      errata.request_docs_approval!
    end

    assert_equal 'errata.activity.docs_approval', topic
    assert_equal({
      'to' => 'docs_approval_requested',
    }, message.slice('to'))
  end

  test 'approving docs sends a message' do
    errata = Errata.where_docs_requested.last
    (topic, message, properties) = message_generated_by do
      errata.approve_docs!
    end

    assert_equal 'errata.activity.docs_approval', topic
    assert_equal({
      'to' => 'docs_approved',
    }, message.slice('to'))
  end

  test 'disapproving docs sends a message' do
    errata = Errata.where_docs_approved.last
    (topic, message, properties) = message_generated_by do
      errata.disapprove_docs!
    end

    assert_equal 'errata.activity.docs_approval', topic
    assert_equal({
      'to' => 'docs_rejected',
    }, message.slice('to'))
  end

  # Note: the release_date field actually contains the embargo date...
  test 'changing embargoed date sends a message' do
    assert !rhba_async.release_date_changed?
    newdate = Time.now

    rhba_async.release_date = newdate
    assert rhba_async.release_date_changed?

    (topic, message, properties) = message_generated_by do
      rhba_async.save!
    end
    assert_equal 'errata.activity.embargo_date', topic
  end

  def message_generated_by(&block)
    jobs = capture_delayed_jobs(/SendMsgJob/) { yield }

    assert_equal 1, jobs.count
    send_msg_job = jobs.first

    topic = send_msg_job.instance_variable_get(:@topic)
    message = send_msg_job.instance_variable_get(:@message)
    properties = send_msg_job.instance_variable_get(:@properties)
    [topic, message, properties]
  end
end
