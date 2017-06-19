require 'test_helper'

class StateTest < ActiveSupport::TestCase
  include State

  test "StateTransitions" do
    trans = State.get_transitions(secalert_user, errata_stub(NEW_FILES), false)
    assert_array_equal([QE, DROPPED_NO_SHIP], trans)

    trans = State.get_transitions(secalert_user, errata_stub(PUSH_READY), false)
    assert_array_equal([DROPPED_NO_SHIP, REL_PREP], trans)

    trans = State.get_transitions(secalert_user, errata_stub(QE, {:docs_approved? => true, :rhnqa? => true}), false)
    assert_array_equal([DROPPED_NO_SHIP, NEW_FILES, REL_PREP], trans)

    trans = State.get_transitions(secalert_user, errata_stub(REL_PREP), false)
    assert_array_equal([DROPPED_NO_SHIP, NEW_FILES, PUSH_READY, QE], trans)

    trans = State.get_transitions(secalert_user, errata_stub(SHIPPED_LIVE), false)
    assert_array_equal([REL_PREP], trans)

    trans = State.get_transitions(secalert_user, errata_stub(DROPPED_NO_SHIP), false)
    assert_array_equal([NEW_FILES], trans)

    [qa_user, releng_user, secalert_user].each do |u|
      trans = State.get_transitions(u, errata_stub(PUSH_READY), false)
      assert trans.include?(REL_PREP), 'Cannot get out of PUSH_READY'
    end
  end

  def errata_stub(state, opts = {})
    opts.reverse_merge!( {:rpmdiff_finished? => true,
                           :tps_finished? => true,
                           :tpsrhnqa_finished? => true,
                           :docs_approved_or_requested? => true,
                           :is_signed? => true,
                           :push_ready_blockers => [],
                           :is_pdc? => false})

    Errata.any_instance.stubs(:status).returns(state)
    Errata.any_instance.stubs(:brew_builds).returns([:b1,:b2])
    Errata.any_instance.stubs(:state_machine_rule_set).returns(StateMachineRuleSet.first)
    Errata.any_instance.stubs(:bugs).returns([:b1,:b2])
    Errata.any_instance.stubs(:build_mapping_class).returns(ErrataBrewMapping)
    Errata.any_instance.stubs(:release_versions_used_by_advisory).returns([])
    Errata.any_instance.stubs(:build_mappings).returns(ErrataBrewMapping.where('1=0'))
    opts.each_pair do |method,value|
      Errata.any_instance.stubs(method).returns(value)
    end

    Errata.new(:release => async_release)
  end
  # nvr: libogg-1.1.3-4.el5_5.1
  # nvr: libogg-1.1.3-4.el5_5.2
  test "test state machine effects" do
    # (Some assertions in this test assume that TPS CDN is disabled)
    Settings.stubs(:enable_tps_cdn).returns(false)

    e = rhba_async
    assert_equal 1, e.state_indices.count
    assert_state_failure(e, QE, "Validation failed: Errata Must complete RPMDiff")
    waive_rpmdiff_runs e

    base_mail_set = ActionMailer::Base.deliveries.to_set
    force_sync_delayed_jobs(/notify/i) do
      verify_qe e
    end
    post_qe_mail = ActionMailer::Base.deliveries.to_set - base_mail_set
    assert_equal 2, e.state_indices.count
    assert_equal 'NEW_FILES', e.current_state_index.previous

    assert e.allow_partner_access?, "No parner access?"

    assert post_qe_mail.any? {|m| m.to == ['partner-testing@redhat.com']}, "No partner mail sent!"

    # For rhel products, we only schedule tps jobs against parent channels
    assert_equal 9, e.tps_run.tps_jobs.count
    assert_equal 0, e.tps_run.rhnqa_jobs.count

    assert_state_failure(e,
                         REL_PREP,
                         ['Validation failed: Errata Must complete TPS',
                          'Errata Must complete TPS RHNQA',
                          'Errata Docs Requested, not yet approved',
                          'Errata Advisory must be up to date on RHN Stage',
                          'Errata Staging push jobs not complete'].join(', '))


    assert !e.tps_finished?, "TPS Shouldn't be done yet."
    finish_tps e
    assert !e.tpsrhnqa_finished?, "TPS RHNQA should not be done yet"
    finish_rhnqa e

    e.request_docs_approval!
    assert_state_failure(e, REL_PREP, "Validation failed: Errata Docs Requested, not yet approved, Errata Staging push jobs not complete")
    e.approve_docs!
    e.stubs(:stage_push_complete?).returns(true)

    verify_rel_prep e

    verify_new_files e

#    map1.obsolete!
    e.build_mappings.each {|m| m.obsolete!}
    build2 = BrewBuild.find_by_nvr 'libogg-1.1.3-4.el5_5.2'
    pv = ProductVersion.find_by_name 'RHEL-5'
    map2 = ErrataBrewMapping.create!(:product_version => pv,
                                    :errata => e,
                                    :brew_build => build2,
                                    :package => build2.package)

    RpmdiffRun.schedule_runs(e)
    assert_state_failure(e, QE, "Validation failed: Errata Must complete RPMDiff")

    waive_rpmdiff_runs e
    verify_qe e

    assert !e.tps_finished?, "TPS Shouldn't be done yet."
    assert !e.tpsrhnqa_finished?, "TPS RHNQA should not be done yet"
    assert_state_failure(e, REL_PREP,
                         "Validation failed: Errata Must complete TPS, Errata Must complete TPS RHNQA, Errata Advisory must be up to date on RHN Stage")

    finish_tps e
    finish_rhnqa e
    verify_rel_prep e

    # Flip back back QE => NEW_FILES => QE without changing builds
    #Tps and rpmdiff should be unchanged.
    verify_qe e
    verify_new_files e

    assert e.rpmdiff_finished?, "RPMDiff should still be complete!"
    verify_qe e

    assert e.tps_finished?, "TPS Should still be complete"
    assert e.tpsrhnqa_finished?, "TPS RHNQA should still be complete"

    assert_state_failure e, REL_PREP, 'Validation failed: Errata Advisory must be up to date on RHN Stage'

    e.update_attribute(:rhnqa, true)
    verify_rel_prep e

    assert_state_failure e, PUSH_READY, 'Validation failed: Errata Packages are not signed'
    key = SigKey.find_by_name! 'master'
    e.brew_builds.each {|b| b.mark_as_signed(key)}

    verify_push_ready e
    assert e.can_push_rhn_live?, e.push_rhn_live_blockers.join(',')

    verify_in_push e
    assert e.can_push_rhn_live?, e.push_rhn_live_blockers.join(',')

    verify_shipped_live e
    assert e.can_push_rhn_live?, e.push_rhn_live_blockers.join(',')
  end

  test "blocking advisory should block" do
    # Actually my new transition guards aren't in the fixtures so
    # have to create them here. TODO: add it to the fixtures...
    StateTransitionGuard.create_guard_helper(IsBlockedGuard)
    StateTransitionGuard.create_guard_helper(IsBlockingGuard)

    # Found these in current fixture data, two REL_PREP advisories
    parent_advisory = Errata.find(10842)
    child_advisory = Errata.find(10718)

    # As mentioned..
    assert_equal REL_PREP, parent_advisory.status
    assert_equal REL_PREP, child_advisory.status

    # Setup dependency
    parent_advisory.blocking_errata << child_advisory

    # Check dependency is there
    assert_equal [child_advisory], parent_advisory.possibly_blocked_by
    assert_equal [parent_advisory], child_advisory.possibly_blocks

    # Should not be able to move parent_advisory to PUSH_READY because
    # it is blocked by child_advisory
    # (Testing IsBlockedGuard)
    assert_state_failure parent_advisory, PUSH_READY,
      "Validation failed: Errata Can't move to PUSH_READY because it is blocked by #{child_advisory.advisory_name}/REL_PREP."

    # Now move child advisory to PUSH_READY
    verify_push_ready child_advisory

    # Now should be able to move parent to PUSH_READY since it's no longer blocked
    verify_push_ready parent_advisory

    # Already checked in the helper methods, but just to clear..
    assert_equal PUSH_READY, parent_advisory.status
    assert_equal PUSH_READY, child_advisory.status

    # Seems like we have to refresh because something is cached in memory.
    # (Maybe dependency_graph?) Is there a nicer way to do this?
    parent_advisory = Errata.find parent_advisory.id
    child_advisory  = Errata.find child_advisory.id

    # (With out the above reload, this fails...)
    assert_equal [parent_advisory], child_advisory.would_block_if_withdrawn

    # At this point if we try to move the child advisory back to REL_PREP it should not
    # be allowed because that would break the dependency rule for the parent advisory
    # (Testing IsBlockingGuard)
    assert_state_failure child_advisory, REL_PREP,
      "Validation failed: Errata Can't move back from PUSH_READY since it would break the dependency rules for: #{parent_advisory.advisory_name}/PUSH_READY."

    # (That's good enough for a quick sanity test).
    # Didn't test IsBlockingGuard when going from SHIPPED_LIVE -> REL_PREP
    # but should work the same as for PUSH_READY -> REL_PREP
  end

  test "sort order sanity" do
    states = State::ALL_STATES
    states.map{ |s| State.sort_order[s] }.each do |sort_order|
      assert sort_order.is_a?(Fixnum)
      assert sort_order >= 0
    end
  end

  test "sort order sanity for weird states" do
    states = %w[ FOO BAR qE NeW_FiLES ]
    states.map{ |s| State.sort_order[s] }.each do |sort_order|
      assert sort_order.is_a?(Fixnum)
      assert_equal(-1, sort_order)
    end
  end

  test "moving advisory to QE requires setting file metadata" do
    e = Errata.find(16397)

    assert e.brew_rpms.empty?
    assert e.brew_files.nonrpm.any?
    assert_equal 'NEW_FILES', e.status

    assert_cannot_move_to_qe = lambda do
      ex = assert_raises(ActiveRecord::RecordInvalid) do
        e.change_state!('QE', devel_user)
      end
      assert_match %r{\bMust set attributes on non-RPM files\b}, ex.message
    end

    assert_cannot_move_to_qe.call()

    # setting the title alone is necessary but not sufficient...
    BrewFileMeta.find_or_init_for_advisory(e).each do |meta|
      meta.title = "title for file #{meta.brew_file_id}"
      meta.save!
    end

    assert_cannot_move_to_qe.call()

    # after setting the rank as well, it's OK
    BrewFileMeta.find_or_init_for_advisory(e).each_with_index do |meta,idx|
      meta.rank = idx
      meta.save!
    end

    assert_nothing_raised do
      e.change_state!('QE', devel_user)
    end
  end

  private

  def assert_state_failure(errata, state, msg, user = qa_user)
    ex = assert_raise(ActiveRecord::RecordInvalid) {errata.change_state!(state, user)}
    assert_equal msg, ex.message
  end

  def finish_tps(e)
    tpsgood = TpsState.find TpsState::GOOD
    e.tps_run.tps_jobs.each {|j| j.update_attribute(:tps_state, tpsgood)}
    assert e.tps_finished?, "TPS Should be finished now."
  end

  def finish_rhnqa(e)
    e.update_attribute(:rhnqa, true)
    Tps::Scheduler.schedule_rhnqa_jobs(e.tps_run)
    tpsgood = TpsState.find TpsState::GOOD
    e.tps_run.rhnqa_jobs.each {|j| j.update_attribute(:tps_state, tpsgood)}
    assert e.tpsrhnqa_finished?
  end

  def verify_new_files(e, user = qa_user)
    e.change_state!(NEW_FILES, user)
    assert_equal NEW_FILES, e.status.to_s
    assert_equal NEW_FILES, e.current_state_index.current
    assert_equal false, e.rhnqa?
    assert_equal false, e.qa_complete?
  end

  def verify_push_ready(e, user = qa_user)
    e.change_state!(PUSH_READY, user)
    assert_equal PUSH_READY, e.status.to_s
    assert_equal PUSH_READY, e.current_state_index.current
    assert_equal true, e.qa_complete?
  end

  def verify_in_push(e, user = releng_user)
    e.change_state!(IN_PUSH, user)
    assert_equal IN_PUSH, e.status.to_s
    assert_equal IN_PUSH, e.current_state_index.current
    assert_equal true, e.qa_complete?
  end

  def verify_qe(e, user = qa_user)
    e.change_state!(QE, user)
    assert_equal QE, e.status.to_s
    assert_equal QE, e.current_state_index.current
  end

  def verify_rel_prep(e, user = qa_user)
    e.change_state!(REL_PREP, user)
    assert_equal REL_PREP, e.status.to_s
    assert_equal REL_PREP, e.current_state_index.current
    assert e.qa_complete?, "QA Should be marked complete"
  end

  def verify_shipped_live(e, user = releng_user)
    e.change_state!(SHIPPED_LIVE, user)
    assert_equal SHIPPED_LIVE, e.status.to_s
    assert_equal SHIPPED_LIVE, e.current_state_index.current
    assert e.qa_complete?, "QA Should be marked complete"
    assert e.published?, "Advisory should be marked as published"
  end

  def waive_rpmdiff_runs(e, user = qa_user)
    e.rpmdiff_runs.unfinished.each {|r| r.update_attribute(:overall_score, RpmdiffScore::WAIVED)}
    e.rpmdiff_runs.unfinished.reload
    assert e.rpmdiff_finished?
  end
end
