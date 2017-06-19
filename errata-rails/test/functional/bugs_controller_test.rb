require 'test_helper'

class BugsControllerTest < ActionController::TestCase

  setup do
    auth_as releng_user
  end

  test "empty bug list for release without blocker flags" do
    release = mock('Release')
    release.expects(:blocker_flags).returns([])
    assert @controller.send('get_bugs_for_release', release).empty?
  end

  test 'added since' do
    e = Errata.new_files.first

    # On the initial request, only include a known set of filed bugs;
    # we can't assume that nobody has added filed bugs to fixtures
    # today
    FiledBug.with_scope(:find => {:conditions => 'filed_bugs.id <= 93858'}) do
      get :added_since, :id => e
    end
    assert_response :success

    # defaults to today
    assert_match /Bugs Added Today/, response.body
    # and there were no bugs added today
    assert_no_match /show_bug\.cgi/, response.body

    bugs = Bug.find(593339, 605956)

    fb = FiledBugSet.new(:bugs => bugs, :errata => e)
    fb.save!

    %w{today yesterday last_week last_month}.each do |timeframe|
      get :added_since, :id => e, :timeframe => timeframe
      assert_response :success
      bugs.each do |bug|
        assert_match bugs_since_pattern(bug), response.body, response.body
      end
    end
  end

  test 'add bugs to errata - no builds' do
    e = Errata.find(11119)
    r = e.release

    # r.bugs.unfiled.where(:bug_status => 'MODIFIED').where(:package_id => r.approved_components).last
    valid_bug = Bug.find(693918)

    # r.bugs.filed.where(:bug_status => 'MODIFIED').where(:package_id => r.approved_components).last
    invalid_filed_bug = Bug.find(495911)

    # r.bugs.unfiled.where(:bug_status => 'NEW').where(:package_id => r.approved_components).last
    invalid_status_bug = Bug.find(698089)

    # Bug.where("flags like '%rhel-5.7.0+%' and ((flags like '%devel_ack+%' and flags like '%qa_ack+%' and flags like '%pm_ack+%') or (keywords like '%Security%') or (is_blocker = 1) or (is_exception = 1))").unfiled.where(:bug_status => %w{MODIFIED VERIFIED}).where('package_id NOT IN (?)', r.approved_components).last
    invalid_not_in_acl_bug = Bug.find(693788)

    # Bug.where(:bug_status => %w{MODIFIED VERIFIED}).where('package_id IN (?)', r.approved_components).where('flags not like "%rhel-5.7.0+%"').first
    invalid_flags_bug = Bug.find(584271)

    get :add_bugs_to_errata, :id => e
    assert_response :success, response.body

    assert_add_bug_show valid_bug, 'failed to show valid bug'
    refute_add_bug_show invalid_filed_bug, 'incorrectly showed already filed bug'
    refute_add_bug_show invalid_status_bug, 'incorrectly showed bug with wrong status'
    refute_add_bug_show invalid_not_in_acl_bug, 'incorrectly showed bug not on ACL'
    refute_add_bug_show invalid_flags_bug, 'incorrectly showed bug with wrong flags'
  end

  test 'add bugs to errata - with builds' do
    e = Errata.find(11036)

    # r.bugs.where(:bug_status => 'MODIFIED').where(:package_id => e.packages.first)
    valid_bug = Bug.find(693759)

    # This bug is valid, but is for a different package.  Should be OK.
    valid_other_package_bug = Bug.find(693918)

    # all other bugs come from above testcase.
    invalid_filed_bug = Bug.find(495911)
    invalid_status_bug = Bug.find(698089)
    invalid_not_in_acl_bug = Bug.find(693788)
    invalid_flags_bug = Bug.find(584271)

    get :add_bugs_to_errata, :id => e
    assert_response :success, response.body

    assert_add_bug_show valid_bug, 'failed to show valid bug'
    assert_add_bug_show valid_other_package_bug, 'failed to show valid bug for other package'
    refute_add_bug_show invalid_filed_bug, 'incorrectly showed already filed bug'
    refute_add_bug_show invalid_status_bug, 'incorrectly showed bug with wrong status'
    refute_add_bug_show invalid_not_in_acl_bug, 'incorrectly showed bug not on ACL'
    refute_add_bug_show invalid_flags_bug, 'incorrectly showed bug with wrong flags'
  end

  test 'add bugs to errata - allow pkg dupes' do
    e1 = Errata.find(11119)
    e2 = Errata.find(11036)
    assert_equal e1.release, e2.release, 'precondition failed - advisories supposed to be for the same release'
    r = e1.release

    b1 = Bug.find(593339)
    b2 = Bug.find(605956)
    assert_equal b1.package, b2.package, 'precondition failed - bugs supposed to be for the same package'

    # initially, should be acceptable to add either bug to either advisory
    [e1,e2].each do |e|
      get :add_bugs_to_errata, :id => e
      assert_response :success, response.body

      assert_add_bug_show b1, 'failed to show valid bug'
      assert_add_bug_show b2, 'failed to show valid bug'
    end

    fb = FiledBugSet.new(:bugs => [b1], :errata => e1)
    fb.save!

    # now e1 is associated with the package.
    # b2 should be eligible to add to e1 only.
    get :add_bugs_to_errata, :id => e1
    assert_response :success, response.body
    assert_add_bug_show b2, 'failed to show valid bug'

    get :add_bugs_to_errata, :id => e2
    assert_response :success, response.body
    refute_add_bug_show b2, 'incorrectly showed bug for a package already having an advisory'

    # If the release allows pkg dupes, b2 should once again be eligible for either advisory.
    r.update_attribute(:allow_pkg_dupes, true)

    [e1,e2].each do |e|
      get :add_bugs_to_errata, :id => e
      assert_response :success, response.body

      assert_add_bug_show b2, 'failed to show valid bug after enabling pkg dupes'
    end
  end

  # This test verifies that the Add Bugs page agrees with the eligibility checklist.
  test 'add bugs to errata - compare with checklist' do
    errata = ENV['TEST_FULL_DATA'] == '1' ? all_add_bugs_errata : Errata.where(:id => [
      # non-ystream
      10858,
      # ystream
      11036
    ]).to_a

    vars = errata.inject({}) do |hsh,e|
      hsh.merge(e => {:errata => e, :release => e.release})
    end

    # ideally, we check all bugs, but it's quite slow.
    # To speed it up, ignore those bugs which are least likely to be handled incorrectly,]
    # and also arbitrarily select only a part of the data
    bugs = ENV['TEST_FULL_DATA'] == '1' ? Bug.all \
      : (i=0; Bug.unfiled.where('bug_status not in (?)', %w{NEW CLOSED}).select{ (i+=1)%4 == 0})
    checklist = BugEligibility::CheckList.new(bugs.first, vars[errata.first])

    errata.each do |e|
      get :add_bugs_to_errata, :id => e
      assert_response :success, response.body

      bugs.each do |b|
        messages = checklist.check(b, vars[e]).checks.map(&:message).join(',')
        if checklist.pass_all?
          assert_add_bug_show b, "for advisory #{e.id}, failed to show bug #{b.id}, which is eligible according to checklist: #{messages}"
        else
          refute_add_bug_show b, "for advisory #{e.id}, incorrectly showed bug #{b.id}, which is ineligible according to checklist: #{messages}"
        end
      end
    end
  end

  test "can find multiple advisories from a bug ID" do
    bug = Bug.find(531697)

    get :errata_for_bug, :id => bug
    assert_response :success
    assert_match /\bRHSA-2011:11065\b/, response.body
    assert_match /\bRHSA-2011:11149\b/, response.body
    assert_no_match /\bNo advisories filed for bug /, response.body
  end

  test "can find zero advisories from a bug ID" do
    bug = Bug.find(189462)

    get :errata_for_bug, :id => bug
    assert_response :success
    assert_match /\bNo advisories filed for bug 189462\b/, response.body
  end

  test "can display qublockers" do
    auth_as admin_user

    get :qublockers
    assert_response :success
    assert response.body =~ /\b(\d+) bugs covered out of (\d+)\b/
    (uncov, total1) = [$1,$2].map(&:to_i)
    assert response.body =~ /\b(\d+) .*\bUncovered\b.* bugs out of (\d+)\b/i
    (cov, total2) = [$1,$2].map(&:to_i)

    assert_equal total1, total2, "bug totals in uncovered/covered sections don't match"
    assert_equal total1, cov+uncov, "covered (#{cov}) + uncovered (#{uncov}) != total (#{total1})"
  end

  test 'can display bugs for an advisory' do
    e = RHBA.find(10836)
    assert e.filed_bugs.length >= 2, 'test data problem: advisory expected to have at least two bugs'

    auth_as qa_user

    get :for_errata, :id => e.id
    assert_response :success, response.body

    e.filed_bugs.each do |fb|
      assert_match %r{\b#{fb.bug.id}\b}, response.body, response.body
    end
  end

  def all_add_bugs_errata
    Errata.new_files.where('errata_type != "RHSA"').select{|e| e.release.blocker_flags?}
  end

  def assert_add_bug_show(bug, message=nil)
    assert_match add_bug_pattern(bug), response.body, "#{message}\n#{response.body}"
  end

  def refute_add_bug_show(bug, message=nil)
    assert_no_match add_bug_pattern(bug), response.body, "#{message}\n#{response.body}"
  end

  def add_bug_pattern(bug)
    /
      <input
      \s[^>]*\b
      id="bug_#{bug.id}"
      \s[^>]*\b
      type="checkbox"
    /x
  end

  def bugs_since_pattern(bug)
    /
      <a\ href="#{Regexp.escape("https://bugzilla.redhat.com/show_bug.cgi?id=#{bug.id}")}">
      #{bug.id}
      <\/a>
      \s*
      \(#{Regexp.escape bug.package.name}\)
      \s* - \s*
      #{bug.bug_status}
      \s* - \s*
      #{Regexp.escape bug.short_desc}
    /x
  end

  test "sync component list for release" do
    release = QuarterlyUpdate.first
    release.class.any_instance.expects(:update_approved_components!).once
    bug_id = 1234 # doesn't matter
    post :troubleshoot_update_approved_components, :bug_id=>bug_id, :release_id=>release.id
    assert_equal "Approved components for #{release.name} synced", flash[:notice]
    assert_redirected_to :controller=>:bugs, :action=>'troubleshoot', :bug_id=>bug_id, :release_id=>release.id
  end

  test "approved_components works for advisories with mixed content" do
    # advisory has rhel-server-docker with RPM and non-RPM files
    e = Errata.find(16396)
    release = e.release

    get :approved_components, :id => release, :format => :json
    assert_response :success, response.body

    data = JSON.load(response.body)
    assert data.include?('rhel-server-docker')

    # seems a bit weird, but this is the output format ...
    assert_equal e.errata_id, data['rhel-server-docker'].try(:[], 'rhba').try(:[], 'id'), data.inspect
  end

  test "approved_components omits non-RPM content from consideration" do
    e = Errata.find(16397)
    pkg = Package.find_by_name!('org.picketbox-picketbox-infinispan')
    assert e.packages.include?(pkg)
    release = e.release

    get :approved_components, :id => release, :format => :json
    assert_response :success, response.body

    data = JSON.load(response.body)

    # package should not be listed since all the content is non-RPM
    refute data.keys.include?(pkg.name)
  end

  test "update bug status - single bug's status update" do
    e = Errata.find(7058)
    bug_a, bug_b = e.bugs

    assert_equal 'CLOSED', bug_a.bug_status
    assert_equal 'CLOSED', bug_b.bug_status
    expected_status_a = 'ASSIGNED'
    expected_status_b = 'CLOSED'
    bug_comment = 'status change'
    param_bugs = {bug_a.id.to_s => expected_status_a, bug_b.id.to_s => ""}
    expected_errata_comment = et_comment(bug_a, expected_status_a, bug_comment)
    expected_bug_comment = bug_comment(bug_a, expected_status_a, e, bug_comment)

    Bugzilla::TestRpc.any_instance.expects(:changeStatus).once.
      with(bug_a.id, expected_status_a, expected_bug_comment).
      returns(true)

    post :updatebugstates, :bug => param_bugs, :id => e.id,
    "bz_#{bug_a.bug_id}_comment" => bug_comment

    e.reload
    bug_a, bug_b = e.bugs
    assert_equal expected_status_a, bug_a.bug_status
    assert_equal expected_status_b, bug_b.bug_status
    assert_equal expected_errata_comment, e.comments.last.text
    assert_redirected_to :controller=>:errata, :action=> :view, :id => e.id
  end

  test "update bug status - multiple bugs's status update" do
    e = Errata.find(7058)
    bug_a, bug_b = e.bugs

    assert_equal 'CLOSED', bug_a.bug_status
    assert_equal 'CLOSED', bug_b.bug_status
    expected_status_a = 'ASSIGNED'
    expected_status_b = 'VERIFIED'
    bug_comment = 'status change'
    param_bugs = {bug_a.id.to_s => expected_status_a, bug_b.id.to_s => expected_status_b}
    expected_errata_a_comment = et_comment(bug_a, expected_status_a, bug_comment)
    expected_errata_b_comment = et_comment(bug_b, expected_status_b, bug_comment)
    expected_errata_comment = expected_errata_a_comment + expected_errata_b_comment
    expected_bug_a_comment = bug_comment(bug_a, expected_status_a, e, bug_comment)
    expected_bug_b_comment = bug_comment(bug_b, expected_status_b, e, bug_comment)

    Bugzilla::TestRpc.any_instance.expects(:changeStatus).once.
      with(bug_a.id, expected_status_a, expected_bug_a_comment).
      returns(true)
    Bugzilla::TestRpc.any_instance.expects(:changeStatus).once.
      with(bug_b.id, expected_status_b, expected_bug_b_comment).
      returns(true)

    post :updatebugstates, :bug => param_bugs, :id => e.id,
    "bz_#{bug_a.bug_id}_comment" => bug_comment,
    "bz_#{bug_b.bug_id}_comment" => bug_comment

    e.reload
    bug_a, bug_b = e.bugs
    assert_equal expected_status_a, bug_a.bug_status
    assert_equal expected_status_b, bug_b.bug_status
    assert_equal expected_errata_comment, e.comments.last.text
    assert_redirected_to :controller=>:errata, :action=> :view, :id => e.id
  end

  test "update bug status - new status already updated to bugzilla" do
    e = Errata.find(7058)
    bug_a, bug_b = e.bugs

    assert_equal 'CLOSED', bug_a.bug_status
    assert_equal 'CLOSED', bug_b.bug_status
    expected_status_a = 'ASSIGNED'
    expected_status_b = 'CLOSED'
    param_bugs = {bug_a.id.to_s => expected_status_a, bug_b.id.to_s => ""}
    expected_flash_message = "Could not update these bugs due " +
      "to state collisions:<br/>Bug #{bug_a.bug_id} already " +
      "changed from #{bug_a.bug_status} to #{expected_status_a}"

    cloned_bug_a = bug_a.clone
    cloned_bug_a.status = expected_status_a
    rpcbug = TestRpcBug.new(cloned_bug_a)

    Bugzilla::TestRpc.any_instance.expects(:get_bugs).once.
      with([bug_a.bug_id]).returns([rpcbug])

    post :updatebugstates, :bug => param_bugs, :id => e.id

    e.reload
    bug_a, bug_b = e.bugs
    # bug new status synced from bugzilla to ET
    assert_equal expected_status_a, bug_a.bug_status
    assert_equal expected_status_b, bug_b.bug_status
    assert_redirected_to :controller=>:errata, :action=> :view, :id => e.id
    assert_equal expected_flash_message, flash[:alert]
  end

  def et_comment(bug, new_state, comment)
    "\n__div_bug_states_separator\n" +
      "bug #{bug.bug_id} changed from #{bug.bug_status} " +
      "to #{new_state}\n#{comment}\n__end_div\n"
  end

  def bug_comment(bug, new_state, errata, comment)
    "Bug report changed from #{bug.bug_status} to #{new_state} " +
      "status by the Errata System: \n" +
      "Advisory #{errata.fulladvisory}: \n" +
      "Changed by: #{releng_user.to_s}\n" +
      "http://errata.devel.redhat.com/advisory/#{errata.id}\n\n#{comment}"
  end

  test 'adding bugs to errata sends a message' do
    errata = Errata.find(11119)
    bug = Bug.find(693918)
    jobs = capture_delayed_jobs(/SendMsgJob/) {
      post :add_bugs_to_errata, :id => errata, :bug => {bug.id => 1}
    }

    assert_equal 1, jobs.count
    send_msg_job = jobs.first

    topic = send_msg_job.instance_variable_get(:@topic)
    message = send_msg_job.instance_variable_get(:@message)
    properties = send_msg_job.instance_variable_get(:@properties)
    assert_equal 'errata.bugs.changed', topic
    assert_equal({
      'added' => [{"id": bug.id, "type": "RHBZ"}].to_json,
      'dropped' => [].to_json,
    }, message.slice('added', 'dropped'))
  end

  test 'removing bugs from errata sends a message' do
    e = Errata.find(11119)
    bug = e.bugs[0]
    jobs = capture_delayed_jobs(/SendMsgJob/) {
      post :remove_bugs_from_errata, :id => e, :bug => {bug.id => 1}
    }

    assert_equal 1, jobs.count
    send_msg_job = jobs.first

    topic = send_msg_job.instance_variable_get(:@topic)
    message = send_msg_job.instance_variable_get(:@message)
    properties = send_msg_job.instance_variable_get(:@properties)
    assert_equal 'errata.bugs.changed', topic
    assert_equal({
      'added' => [].to_json,
      'dropped' => [{"id": bug.id, "type": "RHBZ"}].to_json,
    }, message.slice('added', 'dropped'))
  end

end
