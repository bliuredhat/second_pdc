require 'test_helper'

class ExternalTestRunTest < ActiveSupport::TestCase

  setup do
    @run = ExternalTestRun.find(85)
    assert @run.external_data.empty?
  end

  test 'returns nil if external_message is empty' do
    run = ExternalTestRun.find(82)
    assert_nil run.external_message

    assert_nil run.issue_url
  end

  test 'returns nil if issue URL is not set' do
    run = ExternalTestRun.find(79)
    run.external_message = "run successful"

    assert_nil run.issue_url
  end

  test 'returns issue URL when set' do
    issue_url = Settings.rcm_jira_issue_url % 'KEY-0816'
    run = ExternalTestRun.find(79)
    run.external_message = ["MetadataError", "Updateinfo metadata error", issue_url].join('\n')

    assert_not_nil run.issue_url
    assert_equal run.issue_url, issue_url
  end

  test 'ccat external test run not permitted to reschedule with missing issue URL' do
    run = ExternalTestRun.create!(
      :external_test_type => ExternalTestType.get(:ccat),
      :external_message => "",
      :external_status => 'SUCCESS',
      :external_id => 123,
      :status => 'PASSED',
      :errata => RHEA.first)

    assert_nil run.issue_url
    refute run.reschedule_permitted? devel_user
  end

  test 'ccat external test run not permitted to reschedule with SUCCESS state' do
    run = ExternalTestRun.create!(
      :external_test_type => ExternalTestType.get(:ccat),
      :external_message => Settings.rcm_jira_issue_url % "KEY-1",
      :external_status => 'SUCCESS',
      :external_id => 123,
      :status => 'PASSED',
      :errata => RHEA.first)

    assert run.issue_url
    refute run.reschedule_permitted? devel_user
  end

  test 'ccat external test run permitted to reschedule' do
    run = ExternalTestRun.create!(
      :external_test_type => ExternalTestType.get(:ccat),
      :external_message => Settings.rcm_jira_issue_url % "KEY-1",
      :external_status => '_',
      :external_id => 123,
      :status => 'FAILED',
      :errata => RHEA.first)

    assert run.reschedule_permitted? devel_user
  end

  test "push target can be set successfully on creation" do
    assert_difference('ExternalTestRun.count') do
      ExternalTestRun.create!(
        :external_test_type => ExternalTestType.get(:ccat),
        :external_message => nil,
        :pub_target => 'cdn-live',
        :external_status => 'PASS',
        :external_id => 1,
        :status => 'PASSED',
        :errata => Errata.last)
    end

    run = ExternalTestRun.last
    assert_equal run.external_data, {"pub_target" => 'cdn-live'}
  end

  test "even not configured pub targets can be saved" do
    @run.pub_target = "bar"
    assert @run.valid?
  end

  test "push target can be accessed successfully" do
    cdn_pub_target = 'cdn-live'
    @run.update_attributes({'pub_target' => cdn_pub_target})
    @run.save!

    assert_equal @run.pub_target, cdn_pub_target
    assert_equal @run.external_data, {'pub_target' => cdn_pub_target}
  end

  test "external data attribute can be updated at will" do
    @run.external_data = {'foo' => 'bar'}
    @run.save!

    assert @run.valid?
  end

  test "nothing else than hashes can be saved as external_data" do
    assert_raises(ActiveRecord::SerializationTypeMismatch) do
      @run.external_data = %w(man of my words)
      @run.save!
    end
  end
end
