require 'test_helper'

class RpmdiffControllerTest < ActionController::TestCase

  test "Manage waivers renders result detail instead of log HTML" do
    auth_as devel_user
    expected_content = "Alibaba appear!"

    waiver = RpmdiffWaiver.find(137666)
    result = waiver.rpmdiff_result
    result.rpmdiff_result_details << RpmdiffResultDetail.new(
      :score => RpmdiffScore::WAIVED,
      :result_id => result.id,
      :content => expected_content)
    result.save
    advisory = result.rpmdiff_run.errata_id

    get :manage_waivers, :id => advisory
    assert_response :success
    assert_match %r{#{expected_content}}, response.body
    assert_no_match %r{There are no results to be waived}, response.body
  end

  def test_reschedule_run_works
    # Grab an rpmdiff run to reschedule
    rpmdiff_run = rhba_async.rpmdiff_runs.unfinished.where('obsolete = 0').select{|r|State.open_state?(r.errata.status)}.last

    initial_run_count = RpmdiffRun.count

    # Reschedule it via the reschedule_one action
    auth_as devel_user
    post :reschedule_one, { :run_id => rpmdiff_run.id, :id => rpmdiff_run.errata.id }

    # It should redir back to the rpmdiff run list
    assert_redirected_to :action=>:list, :id=>rpmdiff_run.errata.id

    # This should be the new rpmdiff run
    new_rpmdiff_run = RpmdiffRun.last

    # Did we get the expected flash notice?
    assert_equal "RPMDiff run #{rpmdiff_run.id} has been obsoleted. New run #{new_rpmdiff_run.id} scheduled.", flash[:notice]

    # Run should now be obsolete
    assert rpmdiff_run.obsolete

    # Should be one more run than there was before
    assert_equal initial_run_count + 1, RpmdiffRun.count

    # New run should be similar to old one (sanity check)
    assert new_rpmdiff_run.id > rpmdiff_run.id
    assert_equal [rpmdiff_run.errata, rpmdiff_run.brew_build, rpmdiff_run.new_version, rpmdiff_run.old_version],
      [new_rpmdiff_run.errata, new_rpmdiff_run.brew_build, new_rpmdiff_run.new_version, new_rpmdiff_run.old_version]

  end

  test 'error when reschedule one job' do
    auth_as devel_user

    # Grab an rpmdiff run to reschedule
    rpmdiff_run = rhba_async.rpmdiff_runs.unfinished.where('obsolete = 0').select{|r|State.open_state?(r.errata.status)}.last

    # fake variant to nil to produce error
    RpmdiffRun.any_instance.stubs(:variant).returns(nil)

    assert_no_difference("RpmdiffRun.count") do
      post :reschedule_one, { :run_id => rpmdiff_run.id, :id => rpmdiff_run.errata.id }
    end

    # It should redir back to the rpmdiff run list
    assert_redirected_to :action => :list, :id => rpmdiff_run.errata.id

    expected_message = "Validation failed: Variant can't be blank, Can't schedule RPMDiff run because there is no rhel variant for RHEL-6 release."
    assert_match(expected_message, flash[:alert])
  end

  test 'error when reschedule all jobs' do
    auth_as devel_user

    map_with_rpm = ErrataBrewMapping.for_rpms.first
    map_without_rpm = ErrataBrewMapping.for_nonrpms.first
    map_without_variant = ErrataBrewMapping.for_rpms.first
    map_without_variant.stubs(:rhel_variants).returns([])
    ErrataBrewMapping.stubs(:for_rpms).returns([map_with_rpm, map_without_rpm, map_without_variant])

    errata = Errata.find(7517)

    assert_difference("RpmdiffRun.count", 1) do
      post :reschedule_all, :id => errata.id
    end

    assert_redirected_to :action => :list, :id => errata.id

    # order of these messages is not guaranteed
    expected_messages = [
      "Validation failed: Can't schedule RPMDiff run for "+
        "'org.picketbox-picketbox-infinispan-4.0.9.Final-1' because this brew build " +
        "doesn't contain SRPM.",
      "Validation failed: Variant can't be blank, Can't schedule RPMDiff run " +
        "because there is no rhel variant for RHEL-4 release."
    ]

    expected_messages.each do |msg|
      assert_match(msg, flash[:alert])
    end
  end

  test 'comment can be added without affecting score' do
    auth_as devel_user

    result = RpmdiffResult.find(682031)
    initial_score = result.score
    assert_equal [], result.rpmdiff_waivers.to_a

    post :add_comment, :id => result, :comment => 'trust me'
    assert_response :redirect

    result.reload
    assert_equal ['trust me'], result.rpmdiff_waivers.to_a.map(&:description)

    # adding a comment doesn't affect the score of the result
    assert_equal initial_score, result.score

    # TODO: is it odd that the comment says "has been waived" although the score is unchanged?
    comment = result.rpmdiff_run.errata.comments.last
    assert comment.is_a?(RpmdiffComment)
    assert_match /has been waived.*trust me/m, comment.text
  end

  test 'waiving updates score and adds a comment' do
    auth_as devel_user

    result = RpmdiffResult.find(682031)
    initial_score = result.score
    assert_equal [], result.rpmdiff_waivers.to_a

    post :waive, :id => result, :waive_text => 'trust me'
    assert_response :redirect

    result.reload
    waivers = result.rpmdiff_waivers.to_a
    assert_equal ['trust me'], waivers.map(&:description)
    assert_equal [initial_score], waivers.map(&:old_result)
    assert_equal RpmdiffScore::WAIVED, result.score

    comment = result.rpmdiff_run.errata.comments.last
    assert comment.is_a?(RpmdiffComment)
    assert_match /has been waived.*trust me/m, comment.text
  end

  test 'unwaiving reverts score and adds a comment' do
    auth_as devel_user

    result = RpmdiffResult.find(760552)
    assert_equal RpmdiffScore::WAIVED, result.score, 'precondition failed - result is supposed to be waived!'

    # TODO: why id and result_id?
    post :unwaive, :id => result, :result_id => result, :unwaive_text => 'nuh-uh!'
    assert_response :redirect

    result.reload
    waivers = result.rpmdiff_waivers.order('waiver_id ASC').to_a
    assert_equal [RpmdiffScore::NEEDS_INSPECTION, RpmdiffScore::WAIVED], waivers.map(&:old_result)
    assert_equal ['Generated docs can change in type and size.', 'nuh-uh!'], waivers.map(&:description)
    assert_equal RpmdiffScore::NEEDS_INSPECTION, result.score

    comment = result.rpmdiff_run.errata.comments.last
    assert comment.is_a?(RpmdiffComment)
    assert_match /has been unwaived.*nuh-uh!/m, comment.text
  end

  test 'requesting waivers with mixed permissions works gracefully' do
    auth_as devel_user

    r1 = RpmdiffResult.find(682031)
    r2 = RpmdiffResult.find(760560)
    r3 = RpmdiffResult.find(760561)

    r2.update_attribute(:can_approve_waiver, 'nobody')

    post :request_waivers,
      :id => 10808,
      :request_waiver => {
        r1.id => 1,
        r2.id => 1,
        r3.id => 0,
      },
      :score => {
        r1.id => r1.score
      },
      :waive_text => {
        r1.id => 'test waive'
      },
      :waive_text_shared => ''
    assert_response :redirect

    assert_equal 'You do not have permission to waive result 760560.', flash[:error]
    assert_equal 'Requested waivers for 1 test.', flash[:notice]

    [r1,r2,r3].each(&:reload)
    assert_equal ['test waive'], r1.rpmdiff_waivers.map(&:description)
    assert_equal [], r2.rpmdiff_waivers.map(&:description)
    assert_equal [], r3.rpmdiff_waivers.map(&:description)
  end

  test 'requesting waivers warns about mid-air collisions' do
    auth_as devel_user

    r1 = RpmdiffResult.find(682031)
    r2 = RpmdiffResult.find(760560)

    post :request_waivers,
      :id => 10808,
      :request_waiver => {
        r1.id => 1,
        r2.id => 1,
      },
      :score => {
        r1.id => r1.score,
        r2.id => r2.score - 1
      },
      :waive_text => {
        r1.id => 'test waive.'
      },
      :waive_text_shared => 'shared text.'
    assert_response :redirect

    assert_equal(
      'Result 760560 changed from Needs inspection to Failed after the form
       was loaded. Please review the results again before submitting.'.gsub(/\n\s+/, ' '),
      flash[:error])
    assert_equal 'Requested waivers for 1 test.', flash[:notice]

    [r1,r2].each(&:reload)
    assert_equal ["test waive.\nshared text."], r1.rpmdiff_waivers.map(&:description)
    assert_equal [], r2.rpmdiff_waivers.map(&:description)
  end

  test 'acking/rejecting waivers works as expected and ignores invalid values' do
    auth_as qa_user
    w = RpmdiffWaiver.order('waiver_id ASC').find((52214..52219).to_a)

    post :ack_waivers,
      :id => w[0].rpmdiff_result.rpmdiff_run.errata,
      :ack => {
        w[0].id => 'approve',
        w[1].id => 'approve',
        w[2].id => 'reject',
        w[3].id => 'reject',
        w[4].id => 'frobnitz',
        w[5].id => '',
      },
      :ack_text => {
        w[2].id => 'no good.',
      }

    assert_response :redirect

    w.each(&:reload)
    assert w[0].acked?
    assert w[1].acked?
    refute w[2].acked?
    refute w[3].acked?
    refute w[4].acked?
    refute w[5].acked?

    assert_equal 'An explanation must be provided to reject waiver 52217.<br/>waiver 52218: invalid operation frobnitz', flash[:error]
    assert_equal 'Approved 2 waivers.<br/>Rejected 1 waiver.', flash[:notice]

    # rejecting a waiver is like unwaiving the result
    waivers = w[2].rpmdiff_result.rpmdiff_waivers.order('waiver_id ASC').to_a
    assert_equal 2, waivers.count
    assert_equal w[2], waivers[0]
    assert_equal 'no good.', waivers[1].description
    assert_equal RpmdiffScore::WAIVED, waivers[1].old_result
    assert_equal RpmdiffScore::NEEDS_INSPECTION, w[2].rpmdiff_result.score
  end

  test 'acking waivers posts a comment' do
    auth_as qa_user
    w = RpmdiffWaiver.order('waiver_id ASC').find((52214..52219).to_a)

    post :ack_waivers,
      :id => w[0].rpmdiff_run.errata,
      :ack => {
        w[0].id => 'approve',
        w[1].id => 'approve',
        w[2].id => 'approve',
      },
      :ack_text_shared => 'The Crungey factor can be ignored.'

    expected_comment = (<<-'END_COMMENT').strip_heredoc.chomp
      RPMDiff Run 50224, test "File list" waiver has been approved
      http://errata.devel.redhat.com/rpmdiff/show/50224?result_id=760532
      The Crungey factor can be ignored.

      RPMDiff Run 50224, test "RPM changelog" waiver has been approved
      http://errata.devel.redhat.com/rpmdiff/show/50224?result_id=760526
      The Crungey factor can be ignored.

      RPMDiff Run 50224, test "RPM config/doc files" waiver has been approved
      http://errata.devel.redhat.com/rpmdiff/show/50224?result_id=760527
      The Crungey factor can be ignored.
    END_COMMENT

    assert_equal expected_comment, w[0].rpmdiff_run.errata.comments.last.text
  end

  test 'ack/nack together posts a comment' do
    auth_as qa_user
    w = RpmdiffWaiver.order('waiver_id ASC').find((52214..52219).to_a)

    post :ack_waivers,
      :id => w[0].rpmdiff_result.rpmdiff_run.errata,
      :ack => {
        w[0].id => 'approve',
        w[1].id => 'approve',
        w[2].id => 'reject',
        w[3].id => 'reject',
      },
      :ack_text => {
        w[1].id => 'Can be fixed later.',
        w[2].id => 'Please fix it.',
      },
      :ack_text_shared => 'See also <foo>'

    expected_comment = (<<-'END_COMMENT').strip_heredoc.chomp
      RPMDiff Run 50224, test "File list" has been unwaived
      http://errata.devel.redhat.com/rpmdiff/show/50224?result_id=760532
      Please fix it.
      See also <foo>

      RPMDiff Run 50224, test "RPM requires/provides" has been unwaived
      http://errata.devel.redhat.com/rpmdiff/show/50224?result_id=760542
      See also <foo>

      RPMDiff Run 50224, test "RPM changelog" waiver has been approved
      http://errata.devel.redhat.com/rpmdiff/show/50224?result_id=760526
      See also <foo>

      RPMDiff Run 50224, test "RPM config/doc files" waiver has been approved
      http://errata.devel.redhat.com/rpmdiff/show/50224?result_id=760527
      Can be fixed later.
      See also <foo>
    END_COMMENT

    assert_equal expected_comment, w[0].rpmdiff_run.errata.comments.last.text
  end

  test 'acking/rejecting waivers with mixed permissions works gracefully' do
    auth_as devel_user
    w = RpmdiffWaiver.order('waiver_id ASC').find((52214..52217).to_a)

    w[1].rpmdiff_result.update_attribute(:can_approve_waiver, 'nobody')

    post :ack_waivers,
      :id => w[0].rpmdiff_result.rpmdiff_run.errata,
      :ack => {
        w[0].id => 'approve',
        w[1].id => 'reject',
        w[2].id => 'reject'
      },
      :ack_text => {
        w[1].id => 'no good.',
        w[2].id => 'no good.',
      }

    assert_response :redirect

    w.each(&:reload)
    w.each{|waiver| refute waiver.acked?}

    # only qa can ack waivers, but whoever can create a waiver can also nack a waiver.
    assert_equal 'You do not have permission to approve waiver 52214.<br/>You do not have permission to reject waiver 52215.', flash[:error]
    assert_equal 'Rejected 1 waiver.', flash[:notice]
  end

  test 'interface shows notification if no autowaivers are found' do
    auth_as admin_user

    get :list_autowaive_rules
    assert_response :success
    assert_match %r{\bNo autowaive rules found\b}, response.body
  end

  test 'can search autowaivers successfully' do
    auth_as admin_user

    r1 = rpmdiff_autowaive_rule
    r1.update_attribute(:package_name, 'package1')
    r1.update_attribute(:test_id, 1)
    r1.update_attribute(:active, true)

    r2 = rpmdiff_autowaive_rule
    r2.update_attribute(:package_name, 'package1')
    r2.update_attribute(:test_id, 2)
    r2.update_attribute(:active, true)

    r3 = rpmdiff_autowaive_rule
    r2.update_attribute(:package_name, 'package3')
    r3.update_attribute(:test_id, 3)
    r3.update_attribute(:active, true)

    # can list all autowaivers without filters
    get :list_autowaive_rules

    assert_response :success
    # matches on the css class of the table
    assert_match %r{autowaiver_list}, response.body
    assert_no_match %r{No autowaive rules found}, response.body
    assert_match %r{rpmdiff_autowaive_rule_#{r1.autowaive_rule_id}}, response.body
    assert_match %r{rpmdiff_autowaive_rule_#{r2.autowaive_rule_id}}, response.body
    assert_match %r{rpmdiff_autowaive_rule_#{r3.autowaive_rule_id}}, response.body

    # can search autowaivers with specified filters
    get :list_autowaive_rules, :package => 'package1', :test => 1, :enabled => 'true'
    assert_response :success
    assert_match %r{autowaiver_list}, response.body
    assert_no_match %r{No autowaive rules found}, response.body
    assert_match %r{rpmdiff_autowaive_rule_#{r1.autowaive_rule_id}}, response.body

    # no matched autowaivers
    get :list_autowaive_rules, :package => 'package1', :test => 1, :enabled => 'false'
    assert_response :success
    assert_no_match %r{autowaiver_list}, response.body
    assert_match %r{No autowaive rules found}, response.body
  end

  test 'listed autowaiver rules are sorted by creation date' do
    auth_as admin_user

    r1 = rpmdiff_autowaive_rule
    r1.update_attribute(:created_at, 3.minutes.ago)

    r2 = rpmdiff_autowaive_rule
    assert_not_equal r1, r2

    get :list_autowaive_rules
    assert_response :success

    rules = assigns(:autowaive_rules)
    assert_equal RpmdiffAutowaiveRule.order('created_at DESC').all, rules
  end

  test 'autowaive rule form renders successfully' do
    auth_as admin_user
    detail = RpmdiffResultDetail.last

    get :create_autowaive_rule, :result_detail_id => detail
    assert_response :success
    assert flash.empty?
    assert assigns(:autowaive_rule).product_versions.any?
    assert_equal detail.rpmdiff_result.test_id, assigns(:autowaive_rule).test_id
  end

  test 'create autowaive rule successfully with subpackage' do
    auth_as admin_user

    build = BrewBuild.last

    assert_difference('RpmdiffAutowaiveRule.count') do
      post :manage_autowaive_rule,
        :rpmdiff_autowaive_rule => {
          :content_pattern => '^file.*',
          :reason => 'We know this happens',
          :package_name => build.package_name,
          :subpackage => 'all',
          :score => RpmdiffScore::FAILED,
          :active => '1',
          :product_version_ids => ['', ProductVersion.find_active.first.id.to_s],
          :test_id => RpmdiffTest.find(12).test_id
      }
      assert_redirected_to({:action=>:list_autowaive_rules}, response.body)
    end
  end

  test 'create autowaive rule successfully without subpackage' do
    auth_as admin_user

    build = BrewBuild.last

    assert_difference('RpmdiffAutowaiveRule.count') do
      post :manage_autowaive_rule,
        :rpmdiff_autowaive_rule => {
          :content_pattern => '^file.*',
          :reason => 'We know this happens',
          :package_name => build.package_name,
          :subpackage => '',
          :score => RpmdiffScore::FAILED,
          :active => '1',
          :product_version_ids => ['', ProductVersion.find_active.first.id.to_s],
          :test_id => RpmdiffTest.find(12).test_id
      }
      assert_redirected_to({:action=>:list_autowaive_rules}, response.body)
    end
  end

  test 'successfully update autowaive rule' do
    auth_as admin_user

    rule = rpmdiff_autowaive_rule
    expected = RpmdiffTest.first

    put :manage_autowaive_rule,
      :id => rule.id,
      :rpmdiff_autowaive_rule => rule.attributes.merge(
        {"test_id" => expected.test_id}
    )

    rule.reload

    assert_redirected_to :action=>:list_autowaive_rules
    assert_match %r{\bapplied\b}, flash[:notice]
    assert_equal expected, rule.rpmdiff_test
    assert_nil rule.approved_by
  end

  test 'activating rule sets approved columns successfully' do
    auth_as admin_user

    rule = rpmdiff_autowaive_rule(
      :active => false, :approved_by => nil, :approved_at => nil)

    put :manage_autowaive_rule,
      :id => rule.id,
      :rpmdiff_autowaive_rule => rule.attributes.merge(
        {"active" => "1"}
    )
    assert_response :redirect
    rule.reload

    assert rule.active
    assert_not_nil rule.approved_at
    assert_equal admin_user, rule.approved_by
  end

  test 'error when updating autowaive rule' do
    auth_as admin_user

    rule = rpmdiff_autowaive_rule

    put :manage_autowaive_rule, :id => rule.id,
      :rpmdiff_autowaive_rule => {
        :reason => '',
        :active => true
    }
    assert_response :success
    assert flash[:error].present?
  end

  test 'can load edit form successfully' do
    auth_as admin_user

    get :create_autowaive_rule, :id => rpmdiff_autowaive_rule.id
    assert_response :success
  end

  test 'creating autowaiving rule sets created successfully' do
    auth_as devel_user

    put :manage_autowaive_rule,
      :rpmdiff_autowaive_rule => {
      :content_pattern => '^file.*',
      :reason => 'We know this happens',
      :package_name => BrewBuild.first.package_name,
      :score => RpmdiffScore::FAILED,
      :active => '0',
      :product_version_ids => ['', ProductVersion.find_active.first.id.to_s],
      :test_id => RpmdiffTest.find(12).test_id
    }

    assert_response :redirect, flash[:error]
    assert_nil flash[:error]

    rule = assigns(:autowaive_rule)
    assert_equal devel_user, rule.who
    assert_not_nil rule.created_at
  end

  test 'clone autowaive rule form renders successfully' do
    auth_as devel_user
    rule = rpmdiff_autowaive_rule(
      :active => true, :approved_by => devel_user, :approved_at => Time.now.utc)

    get :clone_single_autowaive_rule, :id => rule.id
    assert_response :success
    assert flash.empty?
    assert_equal rule.who, assigns(:autowaive_rule).who
    refute assigns(:autowaive_rule).active
    assert_not_nil rule.created_at
  end

  test 'clone autowaive rule form renders with QA role' do
    auth_as qa_user
    rule = rpmdiff_autowaive_rule(
      :active => true, :approved_by => devel_user, :approved_at => Time.now.utc)

    # QA role has no permission to clone autowaive rule,
    # will redirect to view autowaive rule page
    get :clone_single_autowaive_rule, :id => rule.id
    assert_response :redirect
    assert_redirected_to :action => :show_autowaive_rule, :id => rule.id
  end

  test "approval info is displayed on result page" do
    auth_as devel_user

    # This run/result should be waived, but otherwise doesn't matter much which
    # we select.
    run = RpmdiffRun.find(50099)
    result = RpmdiffResult.find(756608)
    assert_equal 1, result.rpmdiff_waivers.count, "fixture problem"

    get :show, :id => run.id, :result_id => result.id
    assert_response :success

    under_past_waivers = response.body.gsub(%r{^.*Past Waivers}m, '')
    assert_match %r{Approved by Prasad Pandit}, under_past_waivers
    assert_match %r{Approval text:.{0,40}The explanation looks fine to me\.}m, under_past_waivers
  end

  test "no change made and shows message when failed waiving" do
    auth_as devel_user

    run = RpmdiffRun.find(49946)
    # set errata_brew_mapping to nil to cause a failure
    # while saving RpmdiffRun
    run.errata_brew_mapping = nil
    run.save!(:validate => false)

    result = RpmdiffResult.find(751757)

    assert_equal [
      RpmdiffScore::FAILED,
      RpmdiffScore::FAILED,
      2,
    ], [
      result.rpmdiff_run.overall_score,
      result.score,
      result.rpmdiff_waivers.count
    ]
    initial_waivers = result.rpmdiff_waivers
    initial_score = result.score

    post :waive, :id => result, :waive_text => 'trust me'
    assert_response :redirect

    # It should redir back to the rpmdiff result page
    assert_redirected_to :action => :show, :id => result.rpmdiff_run.run_id, :result_id => result.id

    expected_message = "Validation failed: Errata Brew mapping for RPMDiff run 49946 is missing."
    assert_match(expected_message, flash[:error])

    result.reload

    # There should be no changes when waive failed.
    assert_equal [
      RpmdiffScore::FAILED,
      RpmdiffScore::FAILED,
      2,
    ], [
      result.rpmdiff_run.overall_score,
      result.score,
      result.rpmdiff_waivers.count
    ]
    assert_array_equal initial_waivers, result.rpmdiff_waivers
  end

  test 'reschedule_all will not reuse NVR from previous runs' do
    auth_as devel_user

    errata = Errata.find(20291)

    get_runs = lambda do
      errata.reload.rpmdiff_runs.current.map{ |r| "#{r.old_version} => #{r.new_version}" }.sort
    end

    # This advisory currently has an incrementally scheduled run due to a respin
    assert_equal ['0.10.2-46.el6_6.4 => 0.10.2-46.el6_6.5',
                  '0.10.2-46.el6_6.5 => 0.10.2-46.el6_6.6'], get_runs.call()

    # Now reschedule all...
    post :reschedule_all, :id => errata.id
    assert_response :redirect

    # It should not have considered the "new" of any of those above as
    # candidates for the old version of the newly created runs, since they're
    # obsolete.  It should have created a run comparing the latest released
    # package with what's current on the advisory, ignoring any runs for builds
    # which were previously on the advisory.
    assert_equal ['0.10.2-46.el6_6.4 => 0.10.2-46.el6_6.6'], get_runs.call()
  end
end
