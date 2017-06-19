require 'test_helper'

class ErrataTest < ActiveSupport::TestCase
  setup do
    @rhn_cdn_advisory = Errata.find(10836)
    ActionMailer::Base.deliveries = []
  end
  test "find_by_advisory" do
    assert_raise(BadErrataID) do
      Errata.find_by_advisory(nil)
    end
    assert_raise(BadErrataID) do
      Errata.find_by_advisory("2020:1921")
    end

    e1 = RHBA.create!(:reporter => qa_user,
                      :synopsis => 'test 1',
                      :product => Product.find_by_short_name('RHEL'),
                      :release => async_release,
                      :assigned_to => qa_user,
                      :content =>
                      Content.new(:topic => 'test',
                                  :description => 'test',
                                  :solution => 'fix it')
                      )

    e2 = RHBA.create!(:reporter => qa_user,
                      :synopsis => 'test 2',
                      :product => Product.find_by_short_name('RHEL'),
                      :release => async_release,
                      :assigned_to => qa_user,
                      :content =>
                      Content.new(:topic => 'test',
                                  :description => 'test',
                                  :solution => 'fix it')
                      )
    assert_equal e1, Errata.find_by_advisory(e1.id)
    assert_equal e1, Errata.find_by_advisory(e1.advisory_name)
    assert_equal e1, Errata.find_by_advisory(e1.fulladvisory)

    assert_equal e2, Errata.find_by_advisory(e2.id)
    assert_equal e2, Errata.find_by_advisory(e2.advisory_name)
    assert_equal e2, Errata.find_by_advisory(e2.fulladvisory)

    year = Time.now.year
    e1.old_advisory = e1.fulladvisory
    e1.fulladvisory = "#{e1.errata_type}-#{year}:10010-#{e1.revision}"
    e1.save!

    assert_equal "RHBA-#{year}:10010", e1.advisory_name

    e2.old_advisory = e2.fulladvisory
    e2.fulladvisory = "#{e2.errata_type}-#{year}:1001-#{e2.revision}"
    e2.save!

    assert_equal "RHBA-#{year}:1001", e2.advisory_name

    assert_equal e1, Errata.find_by_advisory(e1.advisory_name)
    assert_equal e1, Errata.find_by_advisory(e1.fulladvisory)
    assert_equal e1, Errata.find_by_advisory(e1.old_advisory)
    assert_equal e1, Errata.find_by_advisory("#{year}:10010")

    assert_equal e2, Errata.find_by_advisory(e2.advisory_name)
    assert_equal e2, Errata.find_by_advisory(e2.fulladvisory)
    assert_equal e2, Errata.find_by_advisory(e2.old_advisory)
    assert_equal e2, Errata.find_by_advisory("#{year}:1001")
  end

  test "Reset of docs ack should move state back from PUSH_READY" do
    with_current_user(qa_user) do
      assert_state_failure(rhba_async, State::QE, "Validation failed: Errata Must complete RPMDiff")
      pass_rpmdiff_runs

      rhba_async.change_state!(State::QE, qa_user)
      rhba_async.approve_docs!
      rhba_async.update_attribute(:rhnqa, true)

      assert_state_failure(rhba_async, State::REL_PREP, 'Validation failed: Errata Must complete TPS, Errata Must complete TPS RHNQA, Errata Staging push jobs not complete')
      Tps::Scheduler.schedule_rhnqa_jobs(rhba_async.tps_run)
      pass_tps_runs
      rhba_async.stubs(:stage_push_complete?).returns(true)

      rhba_async.change_state!(State::REL_PREP, qa_user)

      assert_state_failure(rhba_async, State::PUSH_READY, 'Validation failed: Errata Packages are not signed')
      key = SigKey.find_by_name! 'redhatrelease'
      sign_builds

      rhba_async.change_state!(State::PUSH_READY, qa_user)
      assert_equal State::PUSH_READY, rhba_async.status

      rhba_async.disapprove_docs!
      assert_equal false, rhba_async.doc_complete?
      assert_equal false, rhba_async.text_ready?
      assert_equal State::REL_PREP, rhba_async.status

      rhba_async.change_state!(State::QE, qa_user)
      assert_equal State::QE, rhba_async.status
      rhba_async.disapprove_docs!
      assert_equal State::QE, rhba_async.status
    end
  end

  test "change state" do
    assert_nil rhba_async.tps_run
    assert_state_failure(rhba_async, State::QE, "Validation failed: Errata Must complete RPMDiff")
    pass_rpmdiff_runs
    assert_difference('StateChangeComment.count', 1) do
      assert_difference('ActionMailer::Base.deliveries.length', 3) do
        rhba_async.change_state!(State::QE, qa_user)
      end
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal 'STATE-CHANGE', mail['X-ErrataTool-Action'].value
    assert_equal State::QE, mail['X-ErrataTool-New-Value'].value

    assert_equal(rhba_async.status, State::QE)
    assert_equal(rhba_async.status_updated_at, rhba_async.current_state_index.created_at)
    assert_not_nil rhba_async.tps_run
  end

  # NB: the release_date field actually contains the embargo date...
  test "change embargo date" do
    assert !rhba_async.release_date_changed?
    newdate = Time.now

    rhba_async.release_date = newdate
    assert rhba_async.release_date_changed?
  end

  test "respin" do
    ProductListing.stubs(:get_brew_product_listings => {})
    # Use ErrataBrewMapping.create! to add builds doesn't trigger rpmdiff scheduling
    rhba_async.stubs(:all_builds_have_rpmdiff_scheduled?).returns(true)
    # Bug 1053533: An advisory will be blocked in NEW_FILES state if a build
    # that contains rpms has missing product listing. I will simply mock
    # this check here to make the test easy.
    BuildGuard.any_instance.stubs(:transition_ok? => true)

    assert rhba_async.can_respin?
    pkg = Package.find_by_name 'kernel'
    build = BrewBuild.new(:version => '2.4.21',
                          :release => '32.EL',
                          :package => pkg,
                          :nvr => 'kernel-2.4.21-32.EL')
    build.id = 1
    build.save!


    map1 = ErrataBrewMapping.create!(:product_version => rhba_async.available_product_versions.last,
                                    :errata => rhba_async,
                                    :brew_build => build,
                                    :package => pkg)
    pass_rpmdiff_runs
    rhba_async.change_state!(State::QE, qa_user)
    assert_equal 0, rhba_async.respin_count
    rhba_async.rhnqa = 1
    rhba_async.save!
    assert rhba_async.rhnqa?

    rhba_async.change_state!(State::NEW_FILES, qa_user)
    assert !rhba_async.rhnqa?

    build2 = BrewBuild.new(:version => '2.4.23',
                          :release => '32.EL',
                          :package => pkg,
                          :nvr => 'kernel-2.4.23-32.EL')
    build2.id = 2
    build2.save!

    map1.obsolete!

    map2 = ErrataBrewMapping.create!(:product_version => rhba_async.available_product_versions.last,
                                     :errata => rhba_async,
                                     :brew_build => build2,
                                     :package => pkg)
    pass_rpmdiff_runs
    rhba_async.change_state!(State::QE, qa_user)
    assert_equal 1, rhba_async.respin_count

  end

  test "status_is and status_in methods" do
    # rhba_async is created in test_helper
    # It will have status NEW_FILES
    e = rhba_async

    # status_is? takes a single argument
    assert e.status_is?(:NEW_FILES)
    refute e.status_is?(:SHIPPED_LIVE)

    # status_in? can take one or more args
    assert e.status_in?(:NEW_FILES)
    refute e.status_in?(:REL_PREP)
    assert e.status_in?(:NEW_FILES, :QE)
    refute e.status_in?(:QE, :REL_PREP)
    assert e.status_in?(:QE, :REL_PREP, :NEW_FILES, :SHIPPED_LIVE)

    # actually zero or more args...
    refute e.status_in?

    # There is an arg flatten that lets you do this kind of thing:
    assert e.status_in?([:QE,:REL_PREP,:NEW_FILES])
    assert e.status_in?([:QE,:REL_PREP],:NEW_FILES)
    assert e.status_in?([:QE,:REL_PREP],[:NEW_FILES,:SHIPPED_LIVE])

    # Can can also use strings if you need to
    assert e.status_is?('NEW_FILES')
    refute e.status_is?('REL_PREP')
    assert e.status_in?('NEW_FILES', 'QE')
    refute e.status_in?('REL_PREP', 'QE')

    # Let's make it case insensitive (though for readability
    # don't use this in code)
    assert e.status_is?(:New_Files)
    assert e.status_in?(:new_files,:qe)
    assert e.status_in?('New_fileS','qe')

    # Because of the to_s you can do this also (not sure if useful)
    assert e.status_is?(State::NEW_FILES)
    assert e.status_in?(State::NEW_FILES, State::QE)
    assert e.status_in?(State::open_states)
    refute e.status_in?(State::REL_PREP, State::QE)

    # Typos should throw errors
    assert_raise(NameError) { e.status_is?(:NEW_FILEZ) }
    assert_raise(NameError) { e.status_is?('NEW_FILEZ') }
    assert_raise(NameError) { e.status_in?(:QE,:NEW_FILEZ) }
    assert_raise(NameError) { e.status_in?('QE','RHEL_PREP') }

    # We often use the terminology 'state' so let's provide a synonym
    assert e.state_is? :NEW_FILES
    refute e.state_is? :QE
    assert e.state_in? :NEW_FILES, :QE
    refute e.state_in? :REL_PREP, :QE
  end

  test "Reset default rule set on release or product change" do
      product = Product.find_by_short_name('RHEL')
      content = Content.new(:topic => 'test',
                            :description => 'test',
                            :solution => 'fix it')
      rhba_data = {
        :reporter => qa_user,
        :synopsis => 'advisory',
        :product => product,
        :release => async_release,
        :content => content
      }
      rhba = RHBA.create!(rhba_data)

      #
      # Advisory doesn't change, uses product rule set
      #
      assert_equal product.state_machine_rule_set, rhba.default_state_machine_rule_set
      assert_nil async_release.state_machine_rule_set
      assert_nil rhba.custom_state_machine_rule_set
      refute rhba.has_custom_state_machine_rule_set?

      #
      # Advisory doesn't change, but the product rule set changes
      #
      prs1 = StateMachineRuleSet.create!(:name => 'PR1', :description => 'PR1')
      product.update_attribute('state_machine_rule_set', prs1)
      assert_nil rhba.release.state_machine_rule_set
      assert_equal prs1, rhba.state_machine_rule_set

      #
      # Advisory doesn't change, but the entire product changes
      #
      newprod = Product.find_by_name('BlueGene')
      rhba.update_attribute('product', newprod)
      assert_nil rhba.release.state_machine_rule_set
      assert_equal newprod.state_machine_rule_set, rhba.state_machine_rule_set
      assert_not_equal prs1, newprod.state_machine_rule_set

      #
      # Advisory doesn't change, but now uses the releases rule set
      #
      rs1 = StateMachineRuleSet.create!(:name => 'R1', :description => 'R1')
      async_release.update_attribute('state_machine_rule_set', rs1)
      rhba = RHBA.create!(rhba_data)
      assert_equal rs1, rhba.state_machine_rule_set
      assert_equal rs1, rhba.release.state_machine_rule_set
      refute rhba.has_custom_state_machine_rule_set?

      #
      # Advisory doesn't change, but the release does
      #
      rs2 = StateMachineRuleSet.create!(:name => 'R2', :description => 'R2')
      release = Async.create!(:name => 'Release X',
                              :description => 'rel-x',
                              :state_machine_rule_set => rs2)
      rhba.update_attribute('release', release)
      assert_equal rs2, rhba.state_machine_rule_set
      assert_equal rs2, rhba.release.state_machine_rule_set
      assert_not_equal product.state_machine_rule_set, rhba.state_machine_rule_set
      refute rhba.has_custom_state_machine_rule_set?

      #
      # Advisory with custom rule set, does use neither product or
      # release rule set
      #
      rs3 = StateMachineRuleSet.create!(:name => 'R3', :description => 'R3')
      rhba.update_attribute('state_machine_rule_set', rs3)
      assert rhba.has_custom_state_machine_rule_set?
      assert_equal rs3, rhba.state_machine_rule_set
      assert_not_equal release.state_machine_rule_set, rhba.state_machine_rule_set
      assert_not_equal product.state_machine_rule_set, rhba.state_machine_rule_set

      #
      # Advisory with custom rule set stays the same, release changes
      #
      rhba.update_attribute('release', Release.create!(:name => '3.11',
                                                       :description => 'Test R4',
                                                       :state_machine_rule_set => rs1))
      assert rhba.has_custom_state_machine_rule_set?
      assert_equal rs3, rhba.state_machine_rule_set
      assert_not_nil rhba.release.state_machine_rule_set
      assert_not_equal rhba.release.state_machine_rule_set, rhba.state_machine_rule_set
      assert_not_equal rhba.product.state_machine_rule_set, rhba.state_machine_rule_set

      #
      # Advisory with custom rule set stays the same, product changes
      #
      rhba.update_attribute('product', Product.find_by_short_name('JBEM'))
      assert rhba.has_custom_state_machine_rule_set?
      assert_equal rs3, rhba.state_machine_rule_set
      assert_not_nil rhba.product.state_machine_rule_set
      assert_not_equal rhba.product.state_machine_rule_set, rhba.state_machine_rule_set
  end

  test "related advisories by package" do
    assert Errata.find(16384).has_related_advisories?

    #
    # The advisory's package contains an errata which points to us, so
    # we expect no packages and no advisories
    #
    advisory = Errata.find(13147)
    assert advisory.related_advisories_by_pkg.empty?
    refute advisory.has_related_advisories?
  end

  test "users in the role specified by the info request can clear need info" do
    info_request = InfoRequest.where(:is_active => 1).first
    errata = info_request.errata
    [info_request.info_role.users.first,
     Role.find_by_name('admin').users.first].each do |user|

      assert info_request.who != user
      assert errata.can_clear_info_request?(user)
    end
  end

  test "advisory assignee can clear need info flag" do
    airequest = mock('ActiveInfoRequest')
    airequest.expects(:who).at_least_once.returns(User.last)
    airequest.expects(:info_role).once.returns(Role.last)

    errata = Errata.last
    errata.stubs(:info_requested?).at_least_once.returns(true)
    errata.stubs(:active_info_request).twice.returns(airequest)

    assert User.last != errata.assigned_to
    assert errata.can_clear_info_request?(errata.assigned_to)
  end

  test "brew_builds_by_product_version keeps same return data type" do
    advisory = Errata.find(16409)
    assert advisory.build_mappings.any?
    assert_instance_of Hash, advisory.brew_builds_by_product_version

    #
    # If the list is empty, we still need a Hash, since other code may
    # depend on Hash methods.
    # Bug: 992905
    #
    advisory.stubs(:build_mappings).returns([])
    assert_instance_of Hash, advisory.brew_builds_by_product_version
  end

  test "observer attached" do
    expected_observers = %w{ErrataAuditObserver RssObserver CpeObserver SecurityApprovalObserver}.sort
    [RHSA, RHBA, RHEA].each do |klass|
      assert_equal expected_observers, klass.observer_instances.map { |obj| obj.class.name }.sort
    end
  end

  test "get both jira issues and bugzilla bugs" do
    advisory = Errata.find(10808)
    all_issues = advisory.issue_list
    assert all_issues.any?{ |issue| issue.to_s =~ /^\d+$/ }, "Should contains bugzilla bugs"
    assert all_issues.any?{ |issue| issue.to_s =~ /^[A-Z]+-[0-9]+$/ }, "Should contains jira issues"
  end

  def do_docs_workflow_test(args)
    [:advisory_rule_set, :release_rule_set, :product_rule_set].each do |key|
      args[key] &&= StateMachineRuleSet.find_by_name!(args[key])
    end

    advisory = Errata.last
    advisory.update_attribute(:state_machine_rule_set, args[:advisory_rule_set])
    advisory.release.update_attribute(:state_machine_rule_set, args[:release_rule_set])
    advisory.product.update_attribute(:state_machine_rule_set, args[:product_rule_set])

    included = Errata.with_docs_workflow.include?(advisory)
    assert_equal args[:should_include], included
  end

  test "with docs workflow on errata omits expected advisory" do
    do_docs_workflow_test(
      :advisory_rule_set => 'Unrestricted',
      :should_include => false)
  end

  test "with docs workflow on errata includes expected advisory" do
    do_docs_workflow_test(
      :advisory_rule_set => 'Default',
      :should_include => true)
  end

  test "with docs workflow on release omits expected advisory" do
    do_docs_workflow_test(
      :release_rule_set => 'Unrestricted',
      :should_include => false)
  end

  test "with docs workflow on release includes expected advisory" do
    do_docs_workflow_test(
      :release_rule_set => 'Default',
      :should_include => true)
  end

  test "with docs workflow on product omits expected advisory" do
    do_docs_workflow_test(
      :product_rule_set => 'Unrestricted',
      :should_include => false)
  end

  test "with docs workflow on product includes expected advisory" do
    do_docs_workflow_test(
      :product_rule_set => 'Default',
      :should_include => true)
  end

  test 'brew_rpms returns mapped RPMs' do
    e = Errata.find(16396)
    assert_equal %w[rhel-server-docker-7.0-22.noarch.rpm rhel-server-docker-7.0-22.src.rpm], e.brew_rpms.map(&:rpm_name).sort
  end

  test 'brew_rpms omits unmapped RPMs' do
    e = Errata.find(16396)
    builds = e.brew_builds.to_a
    e.build_mappings.for_rpms.destroy_all
    e.reload

    # removing that mapping shouldn't have removed the entire build,
    # but RPMs are no longer returned by brew_rpms
    assert_equal builds, e.brew_builds.to_a
    assert_equal [], e.brew_rpms
  end

  test "push job since last push_ready" do
    errata = @rhn_cdn_advisory
    method = test_push_jobs_since(errata, "push_ready")

    # Create a new rhn live push job
    # Add 1 minute to prevent last job update time == last change state time
    rhn_live_push_job = RhnLivePushJob.new(:errata => errata, :pushed_by => User.system, :updated_at => Time.now + 1.minute)
    rhn_live_push_job.save!

    assert_equal rhn_live_push_job, errata.send(method, 'rhn_live')
  end

  def test_push_jobs_since(errata, when_state)
    method = :"push_job_since_last_#{when_state}"
    pub_connection = Push::PubClient.get_connection

    # Clean up data before begin
    errata.push_jobs.delete_all

    assert_equal State::PUSH_READY, errata.status

    # Do rhn live push
    errata.change_state!(State::IN_PUSH, admin_user)
    expected_job = RhnLivePushJob.new(:errata => errata, :pushed_by => User.system)
    expected_job.save!
    actual_job = errata.send(method, 'rhn_live')

    assert_equal expected_job, actual_job

    # Make rhn live push fail
    actual_job.mark_as_failed!("Failed to push rhn live")
    errata.reload

    actual_job = errata.send(method, 'rhn_live')

    # No jobs are created since last state change
    assert actual_job.nil?

    return method
  end

  test 'reboot_suggested defaults to false' do
    # Advisory without reboot-suggested packages
    refute Errata.find(19028).reboot_suggested?
  end

  test 'reboot_suggested is true if a pattern is matched' do
    Settings.reboot_suggested_patterns = [%w[.* .* java.*openjdk-d.*]]
    (suggested, why) = Errata.find(19028).reboot_suggested_with_reasons

    assert suggested
    assert_equal [
      "Ships java-1.8.0-openjdk-debuginfo to RHEL-6.6.Z",
      "Ships java-1.8.0-openjdk-demo to RHEL-6.6.Z",
      "Ships java-1.8.0-openjdk-devel to RHEL-6.6.Z",
    ], why
  end

  test 'reboot_suggested matches on product' do
    Settings.reboot_suggested_patterns = [%w[ABC .* .*]]
    (suggested, why) = Errata.find(19028).reboot_suggested_with_reasons

    # It should not be suggested, since product didn't match
    refute suggested
    assert_equal [
      "Doesn't ship any reboot-suggested package",
    ], why
  end

  test 'reboot_suggested pattern matches on RHEL release' do
    # In this test, we use an ASYNC advisory with files for both RHEL 6
    # and RHEL 7, and set up the pattern to only match for RHEL 7.
    Settings.reboot_suggested_patterns = [%w[.* RHEL-7.* .*]]
    errata = Errata.find(19828)

    pv = errata.current_files.map(&:variant).map(&:product_version).map(&:name).uniq.sort
    assert_equal %w[RHEL-6.6.z RHEL-7.0.Z], pv, "fixture problem"

    (suggested, why) = errata.reboot_suggested_with_reasons

    assert suggested
    why.each do |reason|
      assert_match /^Ships .* to RHEL-7\.0\.Z$/, reason
    end
  end

  test 'moving multi-product errata from NEW_FILES to QE notifies' do
    # Necesary due to insufficient product listing fixture data
    ProductListingCache.any_instance.stubs(:empty?).returns(false)
    multi_product_new_files_errata.change_state!('QE', devel_user)
    assert has_multi_product_to_qe_mail?
  end

  test 'toggling multi-product errata in NEW_FILES does not notify' do
    e = multi_product_new_files_errata
    e.supports_multiple_product_destinations = false
    e.save!
    e.supports_multiple_product_destinations = true
    e.save!

    refute has_multi_product_to_qe_mail?
    refute has_multi_product_activated_mail?
  end

  test 'toggling multi-product errata in QE notifies' do
    e = multi_product_new_files_errata
    e.supports_multiple_product_destinations = false
    e.save!
    e.change_state!('QE', devel_user)

    refute has_multi_product_to_qe_mail?
    refute has_multi_product_activated_mail?

    e.supports_multiple_product_destinations = true
    e.save!

    refute has_multi_product_to_qe_mail?
    assert has_multi_product_activated_mail?
  end

  test 'toggling multi-product errata in QE does not notify if no multi-product mappings' do
    e = multi_product_new_files_errata
    e.supports_multiple_product_destinations = false
    e.save!
    e.change_state!('QE', devel_user)

    MultiProductChannelMap.with_scope(:find => {:conditions => '0 = 1'}) do
      MultiProductCdnRepoMap.with_scope(:find => {:conditions => '0 = 1'}) do
        e.supports_multiple_product_destinations = true
        e.save!
      end
    end

    refute has_multi_product_to_qe_mail?
    refute has_multi_product_activated_mail?
  end


  test 'partner access allowed after embargo date passed' do
    time = Time.now.beginning_of_day

    e = rhba_async
    e.embargo_date = time + 10.days
    e.save!

    # Is not partner-accessible prior to release date
    refute e.allow_partner_access?

    # Still not partner-accessible during the release date
    Time.stubs(:now => time + 10.days + 8.hours)
    refute e.allow_partner_access?

    # It is accessible after the release date strictly passed
    Time.stubs(:now => time + 11.days)
    assert e.allow_partner_access?
  end

  test 'partner access allowed after embargo date unset' do
    time = Time.now.beginning_of_day

    e = rhba_async
    e.embargo_date = time + 10.days
    e.save!

    # Is not partner-accessible prior to release date
    refute e.allow_partner_access?

    # It is accessible after the date is unset
    e.embargo_date = nil
    e.save!

    assert e.allow_partner_access?
  end

  test 'partner access is blocked on embargoed bugs' do

    e = rhba_async

    # Baseline: partner access is allowed
    assert e.allow_partner_access?

    ok_bugs        = Bug.where(:is_private => false).limit(4).to_a
    embargoed_bugs = Bug.joins(:package).readonly(false).where(
                                                               :is_security => true,
                                                               :is_private => true,
                                                               :packages => {
                                                                 :name => 'vulnerability'
                                                               }).limit(3).to_a

    # It should still be allowed after adding a regular bug
    file_bug e, ok_bugs[0]
    assert e.reload.allow_partner_access?

    # It should no longer be allowed after adding an embargoed bug
    file_bug e, embargoed_bugs[0]
    refute e.reload.allow_partner_access?

    # If the embargoed bug were to become unembargoed, it's OK to share again.
    # (note: no grace period applies)
    embargoed_bugs[0].update_attributes(:is_private => false)
    assert e.reload.allow_partner_access?

    # If one of our bugs blocks an embargoed bug, it's not allowed
    ok_bugs[0].blocks << embargoed_bugs[1]
    refute e.reload.allow_partner_access?

    # If the dependency disappears, it's OK to share again
    embargoed_bugs[1].depends_on = []
    assert e.reload.allow_partner_access?

    # depending on embargoed bug doesn't make a difference to the result
    ok_bugs[0].depends_on << embargoed_bugs[1]
    assert e.reload.allow_partner_access?

    # indirectly blocking an embargoed bug doesn't make a difference to the result
    ok_bugs[0].blocks << ok_bugs[1]
    ok_bugs[1].blocks << embargoed_bugs[2]
    assert e.reload.allow_partner_access?
  end

  test 'embargoed_bugs must have vulnerability package' do

    e = rhba_async

    # Baseline: partner access is allowed
    assert e.allow_partner_access?

    vulnerability_package = Package.where(:name => 'vulnerability').last
    non_vulnerability_package = Package.where('name != "vulnerability"').last
    private_bug = Bug.where(:is_security => false, :is_private => true).last
    security_bug = Bug.where(:is_security => true, :is_private => false).last
    non_private_security_bug = Bug.where(:is_security => false, :is_private => false).last
    private_security_bug = Bug.where(:is_security => true, :is_private => true).last

    # It allows partner access when has any private or security bugs with non vulnerability
    # package
    [ private_bug, security_bug, non_private_security_bug, private_security_bug ].each do |bug|
      bug.update_attributes(:package_id => non_vulnerability_package.id)
      file_bug e, bug
      assert e.reload.allow_partner_access?
    end

    # It allows partner access when has any private OR security bugs with vulnerability
    # package but not private AND security bug with vulnerability package
    [ private_bug, security_bug, non_private_security_bug ].each do |bug|
      bug.update_attributes(:package_id => vulnerability_package.id)
      assert e.reload.allow_partner_access?
    end

    # It doesn't allow partner access when has private and security bug with vulnerability
    # package
    private_security_bug.update_attributes(:package_id => vulnerability_package.id)
    refute e.reload.allow_partner_access?

  end

  # Helper to file a bug on advisory while bypassing validations (because it's
  # complicated to satisfy bug eligibility, and unrelated to this test)
  def file_bug(errata, bug)
    FiledBug.
      new(:errata => errata, :bug => bug, :user => User.current_user).
      save!(:validate => false)
  end

  def multi_product_new_files_errata
    Errata.find(20291).tap do |e|
      assert e.supports_multiple_product_destinations?, 'fixture problem'
      assert_equal 'NEW_FILES', e.status, 'fixture problem'
    end
  end

  def has_multi_product_to_qe_mail?
    has_mail_including?("A multi-product advisory is available for testing.")
  end

  def has_multi_product_activated_mail?
    has_mail_including?("Multi-product support has been enabled on an advisory.")
  end

  def has_mail_including?(needle)
    ActionMailer::Base.deliveries.any? do |m|
      m.body.to_s.include?(needle)
    end
  end
end


class DependentErrataTest < ActiveSupport::TestCase

  setup do
    @rhn_advisory = Errata.find(11152)
    @rhn_blocker = Errata.qe.first

    @cdn_advisory = Errata.find(16374)
    @cdn_blocker = Errata.qe.last

    @rhn_advisory.blocking_errata << @rhn_blocker
    @cdn_advisory.blocking_errata << @cdn_blocker
  end

  test "ensure fixture data is correctly setup" do
    assert_equal [@rhn_blocker], @rhn_advisory.blocking_errata
    assert_equal [@cdn_blocker], @cdn_advisory.blocking_errata
    assert @rhn_advisory.dependent_errata.empty?
    assert @cdn_advisory.dependent_errata.empty?
    refute @rhn_blocker.has_pushed_rhn_stage?
    refute @rhn_advisory.has_pushed_rhn_stage?
    refute @cdn_blocker.has_pushed_cdn_stage?
  end

  # See Bug 902226
  test "dependencies block rhn stage push" do
    # Sanity check
    assert_equal [@rhn_advisory], @rhn_blocker.dependent_errata
    assert_equal [@rhn_blocker],  @rhn_advisory.blocking_errata

    # Check some methods in errata_dependency_graph
    # These methods traverse down the deps tree, but not testing that here).
    assert_equal [@rhn_advisory], @rhn_blocker.possibly_blocks
    assert_equal [@rhn_blocker],  @rhn_advisory.possibly_blocked_by

    # These are based on shipped status. (Nothing to do with rhn
    # stage but might as well test them anyway).
    assert_equal [@rhn_advisory], @rhn_blocker.currently_blocks
    assert_equal [@rhn_blocker],  @rhn_advisory.currently_blocked_by

    # This part is new for Bug 902226
    assert_equal [@rhn_blocker], @rhn_advisory.currently_blocked_for_rhn_stage_by
    assert_equal 1, @rhn_advisory.push_rhn_stage_blockers.grep(/^Must push dependencies/).length
  end

  test "dependencies will not block non supported push targets" do
    assert_equal [], @rhn_advisory.currently_blocked_for_cdn_stage_by
    assert_equal [], @cdn_advisory.currently_blocked_for_rhn_stage_by
  end

  test "dependencies block cdn stage push" do
    assert_equal [@cdn_blocker], @cdn_advisory.currently_blocked_for_cdn_stage_by
    assert_equal 1, @cdn_advisory.push_cdn_stage_blockers.grep(/^Must push dependencies/).length
  end

  test "pushed blocker advisory allows to push dependent advisory" do
    # Once it's pushed then it doesn't block any more
    @rhn_blocker.update_attribute('rhnqa', true)
    assert @rhn_advisory.currently_blocked_for_rhn_stage_by.empty?
    assert @rhn_advisory.push_rhn_stage_blockers.grep(/^Must push dependencies/).empty?
  end

  test "child blocker blocks parent blocked advisory" do
    secondary_blocker = Errata.new_files.last
    @rhn_blocker.blocking_errata << secondary_blocker
    @rhn_blocker.update_attribute('rhnqa', true)
    assert_equal [@rhn_blocker, secondary_blocker],  @rhn_advisory.possibly_blocked_by
    assert_equal [@rhn_blocker, secondary_blocker],  @rhn_advisory.currently_blocked_by
    assert_equal [secondary_blocker],           @rhn_advisory.currently_blocked_for_rhn_stage_by
    assert_equal 1, @rhn_advisory.push_rhn_stage_blockers.grep(/^Must push dependencies/).length
  end

  test "child blockers need to be pushed before parent advisory can be pushed" do
    secondary_blocker = Errata.new_files.last
    secondary_blocker.update_attribute('rhnqa', true)
    @rhn_blocker.blocking_errata << secondary_blocker
    @rhn_blocker.update_attribute('rhnqa', true)

    assert @rhn_advisory.currently_blocked_for_rhn_stage_by.empty?
    assert @rhn_advisory.push_rhn_stage_blockers.grep(/^Must push dependencies/).empty?
  end

  test "a blocked advisory can't be pushed to stage" do
    BlockingIssue.create!(:errata => rhba_async,
                          :who => releng_user,
                          :summary => 'block',
                          :description => 'block',
                          :blocking_role => releng_user.roles.first
                         )

    assert rhba_async.is_blocked?
    assert_match %r{Advisory is blocked}, rhba_async.common_stage_blockers(:cdn_stage).last
  end

  test "push live blockers" do
    assert rhba_async.push_rhn_live_blockers.length > 0
    assert !rhba_async.can_push_rhn_live?
    rhba_async.rhnqa = 1
    assert !rhba_async.can_push_rhn_live?
    rhba_async.doc_complete = 1
    assert !rhba_async.can_push_rhn_live?
    rhba_async.text_ready = 0
    assert !rhba_async.can_push_rhn_live?
    rhba_async.status = State::PUSH_READY
    sign_builds
    assert rhba_async.can_push_rhn_live?, rhba_async.push_rhn_live_blockers.join(',')
  end

  test "push stage blockers" do
    assert rhba_async.push_rhn_stage_blockers.length > 0
    assert !rhba_async.can_push_rhn_stage?
    assert_state_failure(rhba_async, State::QE, "Validation failed: Errata Must complete RPMDiff")
    pass_rpmdiff_runs
    rhba_async.change_state!(State::QE, qa_user)

    arch = Arch.find_by_name('i386')
    variant = Variant.find_by_name('5Server')

    job1 = RhnTpsJob.create!(:run => rhba_async.tps_run,
                             :arch => arch,
                             :variant => variant,
                             :channel => PrimaryChannel.find_by_arch_id_and_variant_id(arch, variant)
                            )
    arch = Arch.find_by_name('x86_64')
    job2 = RhnTpsJob.create!(:run => rhba_async.tps_run,
                             :arch => arch,
                             :variant => variant,
                             :channel => PrimaryChannel.find_by_arch_id_and_variant_id(arch, variant)
                            )
    rhba_async.reload

    assert !rhba_async.tps_finished?
    assert !rhba_async.can_push_rhn_stage?
    assert rhba_async.push_rhn_stage_blockers.include?('TPS testing incomplete')
    rhba_async.tps_run.update_job(job1,
                                   TpsState.find(TpsState::WAIVED),
                                                 nil,
                                                 nil)
    rhba_async.reload
    assert !rhba_async.tps_finished?
    assert !rhba_async.can_push_rhn_stage?
    assert rhba_async.push_rhn_stage_blockers.include?('TPS testing incomplete')

    rhba_async.tps_run.update_job(job2,
                                   TpsState.find(TpsState::WAIVED),
                                                 nil,
                                                 nil)
    pass_tps_runs
    assert rhba_async.tps_finished?
    assert !rhba_async.can_push_rhn_stage?
    assert_equal ['Packages are not signed'], rhba_async.push_rhn_stage_blockers
    sign_builds
    rhba_async.reload
    assert rhba_async.can_push_rhn_stage?, rhba_async.push_rhn_stage_blockers.join("\n")
  end

  test 'push blockers memoized' do
    [:cdn, :cdn_stage, :rhn_live, :rhn_stage, :ftp, :altsrc,
     :cdn_if_live_push_succeeds].each do |type|
      msg             = "failed for #{type}"
      target_method   = :"push_#{type}_blockers_without_memo"
      blockers_method = :"push_#{type}_blockers"
      can_push_method = :"can_push_#{type}?"

      e = Errata.first

      blockers = ["can't push #{type} 1"]
      e.expects(target_method).with().once.returns(blockers)
      assert_equal blockers, e.send(blockers_method), msg
      assert_equal blockers, e.send(blockers_method), msg
      assert_equal blockers, e.push_blockers_for(type), msg
      refute e.send(can_push_method), msg
      refute e.can_push_to?(type), msg

      # different options should be memoized separately
      blockers = ["can't push #{type} 2"]
      e.expects(target_method).with({:foo => :bar}).once.returns(blockers)
      assert_equal blockers, e.send(blockers_method, {:foo => :bar}), msg
      assert_equal blockers, e.send(blockers_method, {:foo => :bar}), msg
      assert_equal blockers, e.push_blockers_for(type, {:foo => :bar}), msg
      refute e.send(can_push_method, {:foo => :bar}), msg
    end
  end

  test 'push blocker memo cleared on reload' do
    e = Errata.first

    blockers = ["can't push"]

    # twice in total
    e.expects(:push_rhn_live_blockers_without_memo).with().twice.returns(blockers)

    # once for these...
    assert_equal blockers, e.push_rhn_live_blockers
    assert_equal blockers, e.push_rhn_live_blockers

    e.reload

    # ...and once for these
    assert_equal blockers, e.push_rhn_live_blockers
    assert_equal blockers, e.push_rhn_live_blockers
  end

  test 'push blocker memo cleared on change' do
    e = Errata.first

    blockers = ["can't push"]

    # thrice in total
    e.expects(:push_rhn_live_blockers_without_memo).with(:foo).times(3).returns(blockers)

    # once for these...
    assert_equal blockers, e.push_rhn_live_blockers(:foo)
    assert_equal blockers, e.push_rhn_live_blockers(:foo)

    e.synopsis = e.synopsis + ' - modified'

    # ...and once each for these
    assert_equal blockers, e.push_rhn_live_blockers(:foo)
    assert_equal blockers, e.push_rhn_live_blockers(:foo)
  end

  test 'can live push nochannel in stage states' do
    e = Errata.find(10718)

    # cannot do a normal live push...
    assert_match 'State REL_PREP invalid', e.live_push_blockers.join

    # ...but nochannel pub option makes it OK
    assert_equal [], e.live_push_blockers({'nochannel' => true})
  end

  test 'has_pushed does not count nochannel pushes' do
    e = Errata.find(19029)
    pj = CdnPushJob.find(47972)

    # This errata has a completed nochannel push job since last respin
    assert_equal e, pj.errata
    assert_not_nil pj.pub_task_id
    assert pj.pub_options['nochannel']
    assert_equal 'COMPLETE', pj.status
    assert e.push_jobs_since_last_state(CdnPushJob, 'NEW_FILES').include?(pj)

    # ...but it does not count to has_pushed
    refute e.has_pushed_since_last_respin?(CdnPushJob)
  end

  test "blocker error message reflects unsupported cdn stage" do
    rhba_async.expects(:supports_cdn_stage?).returns(false)

    assert_match %r{not support Cdn Stage}, rhba_async.push_cdn_stage_blockers.first
  end

  test "push cdn stage blockers fail if unsigned" do
    rhba_async.expects(:is_signed?).returns(false)

    assert_match %r{not signed}, rhba_async.push_cdn_stage_blockers.first
  end

  test "push cdn stage blockers fail if invalid state" do
    rhba_async.expects(:is_signed?).returns(true)

    assert_match %r{State invalid}, rhba_async.push_cdn_stage_blockers.first
  end

  test "missing cdn support reflected by push cdn blockers " do
    # advisory without CDN support
    advisory = Errata.find(10205)

    refute advisory.supports_cdn?
    assert_match %r{Does not support Cdn}, advisory.push_cdn_blockers.first
    assert_equal 1, advisory.push_cdn_blockers.count
  end

  test "fail ftp push if product does not support ftp" do
    advisory = Errata.find(16374)

    refute advisory.product.allow_ftp?
    assert_match %r{Cannot push.*to FTP}, advisory.push_ftp_blockers.first
    assert_equal 1, advisory.push_ftp_blockers.count
  end

  # There's special logic regarding when an FTP push can be done, in
  # relation to other push types.
  # This helper method is intended for testing that.
  def do_can_push_ftp_test(opts={})
    e = Errata.find(10836)

    assert_equal 'PUSH_READY', e.status

    # initially, supports all the relevant push targets
    e.push_targets.map(&:name).to_set.tap{|targets|
      assert targets.superset?( %w[rhn_live cdn ftp].to_set ), targets.inspect
    }

    # filter push targets if requested
    if filter=opts[:select_targets]
      e.available_product_versions.each do |pv|
        pv.push_targets = pv.push_targets.select(&filter)
      end

      # Avoiding e.reload because e.supported_push_types is memoized
      e = Errata.find(e.id)

      # Ensure the filtering really worked
      assert e.push_targets.reject(&filter).empty?, e.push_targets.map(&:name).inspect
    end

    # ensure not already pushed to RHN or CDN live
    assert_equal [], e.push_jobs.where(:type => [RhnLivePushJob, CdnPushJob].map(&:to_s)).to_a

    assert e.can_push_ftp?, e.push_ftp_blockers.join(',')
  end

  test "advisory with cdn, rhn, ftp can push FTP" do
    do_can_push_ftp_test
  end

  test "advisory with rhn, ftp can push FTP" do
    do_can_push_ftp_test(:select_targets =>
      lambda{|target| target.name == 'ftp' || target.name.starts_with?('rhn')})
  end

  test "advisory with cdn, ftp can push FTP" do
    do_can_push_ftp_test(:select_targets =>
      lambda{|target| target.name == 'ftp' || target.name.starts_with?('cdn')})
  end

  test "advisory with ftp only can push FTP" do
    do_can_push_ftp_test(:select_targets =>
      lambda{|target| target.name == 'ftp'})
  end

  test "raises error if push blocker is not implemented" do
    assert_raise(NameError) { e.push_blockers_for(:beer_in_the_fridge) }
  end

  test "can successfully look up push blocker" do
    rhba_async.expects(:common_stage_blockers)
    rhba_async.push_blockers_for(:cdn_stage)
  end

  test "raises error if queried for invalid push target" do
    assert_raise(NameError) { e.can_push_to?(:beer_in_the_fridge) }
  end

  test "can successfully look up push target" do
    rhba_async.expects(:push_cdn_stage_blockers).returns([])
    rhba_async.can_push_to?(:cdn_stage)
  end

  test 'advisory with no RPMs is considered signed' do
    assert Errata.find(16397).is_signed?
  end

  test 'advisory with RPMs and non-RPMs is considered unsigned if any RPMs are unsigned' do
    refute Errata.find(16396).is_signed?
  end

  test 'advisory with RPMs and non-RPMs is considered signed if all RPMs are signed' do
    Errata.find(16396).tap{|e|
      e.brew_files.rpm.update_all(:is_signed => true)
      assert e.is_signed?
    }
  end

  test 'having a non-RPM mapping to an unsigned build with RPMs does not affect whether an advisory is signed' do
    bb = BrewBuild.find_by_nvr!('spice-client-msi-3.4-4')
    assert bb.brew_rpms.any?
    refute bb.signed_rpms_written?
    nonrpm_type = bb.brew_files.map(&:brew_archive_type_id).compact.first
    assert_not_nil nonrpm_type

    Errata.find(16396).tap{|e|
      e.build_mappings.for_rpms.map(&:brew_build).uniq.each{|b| b.update_attribute(:signed_rpms_written, true)}
      e.brew_files.rpm.update_all(:is_signed => true)
      ErrataBrewMapping.create!(
        :errata => e,
        :brew_build => bb,
        :package => bb.package,
        :product_version => e.available_product_versions.first,
        :brew_archive_type_id => nonrpm_type
      )
      e.reload

      # There's now an associated build whose RPMs are not signed.
      # However, since those RPMs aren't mapped into this advisory, it doesn't affect the result;
      # it's still considered signed.
      assert e.is_signed?

      ErrataBrewMapping.create!(
        :errata => e,
        :brew_build => bb,
        :package => bb.package,
        :product_version => e.available_product_versions.first
      )
      e.reload

      # Now we've mapped the unsigned RPMs as well, the advisory is no longer signed.
      refute e.is_signed?
    }
  end

  test 'brew_rpms method is cached and the cache is cleared after calling reload' do
    e = Errata.find(16396)
    assert e.instance_variable_get("@_brew_rpms").nil?

    # Calling brew_rpms sets @_brew_rpms
    rpms1 = e.brew_rpms
    assert_equal e.instance_variable_get("@_brew_rpms"), rpms1

    # Confirm cache is used on subsequent call
    e.expects(:build_mappings).never
    rpms2 = e.brew_rpms
    assert_equal rpms1, rpms2

    # Confirm cache is cleared after reload
    e.reload
    assert e.instance_variable_get("@_brew_rpms").nil?
  end

  test 'errata_public_url always uses CDN link' do
    e = Errata.first
    e.expects(:advisory_name).at_least_once.returns('RHBA-2013:1234-01')

    expected_url = 'https://access.redhat.com/errata/RHBA-2013:1234-01'

    # truth table covering all has pushed / has content RHN combinations
    [
      [false, false], [false, true], [true,  false], [true,  true],
    ].each do |has_rhn_live,pushed_rhn_live|
      e.stubs(
        :has_rhn_live? => has_rhn_live,
        :has_pushed_rhn_live? => pushed_rhn_live)
      assert_equal(expected_url, e.errata_public_url,
        "url mismatch when has rhn: #{has_rhn_live}, pushed rhn: #{pushed_rhn_live}")
    end
  end

  test "test deprecated errata_id" do
    et_scope = Errata.includes(:live_advisory_name)
    not_live, live = et_scope.partition{|e| e.live_advisory_name.nil? }

    errata_1 = not_live.first
    errata_2 = live.first

    assert_equal errata_1.id, errata_1.errata_id
    assert_equal errata_2.live_advisory_name.live_id, errata_2.errata_id
  end

  test "update full advisory when revision increased" do
    original_full_advisory = rhba_async.fulladvisory
    rhba_async.save!

    # no change if revision is same
    assert_equal original_full_advisory, rhba_async.fulladvisory

    rhba_async.revision += 1
    rhba_async.save!

    assert_equal original_full_advisory.next, rhba_async.fulladvisory
  end

  test "update full advisory when errata type is changed" do
    from_type = "RHBA"
    to_type = "RHEA"

    errata = from_type.constantize.first
    errata.errata_type = from_type
    errata.save!

    # nothing change
    assert_match(/^#{from_type}/, errata.fulladvisory)

    errata.errata_type = to_type
    errata.save!

    assert_match(/^#{to_type}/, errata.fulladvisory)
  end

  test "always use the live id to set full advisory if there is one" do
    errata = Errata.shipped_live.first

    errata.change_state!(State::REL_PREP, @rel_eng)
    errata.save!

    type = errata.errata_type
    year = errata.live_advisory_name.year
    id   = sprintf("%.4d",errata.live_advisory_name.live_id)
    rev  = sprintf("%.2d",errata.revision)
    expected = "#{type}-#{year}:#{id}-#{rev}"

    assert_equal expected, errata.fulladvisory
  end

  test "oval errata id" do
    errata = Errata.find(16397)
    assert_equal "201416397", errata.oval_errata_id

    invalid_id = "RHSA-BLAH:XXXX-01"
    error = assert_raises(ArgumentError) do
      errata.fulladvisory = invalid_id
      errata.oval_errata_id
    end

    assert_equal "Invalid full advisory '#{invalid_id}'", error.message
  end

  test "get variants used by an advisory" do
    errata = [
      "RHSA-2014:2021",
      "RHSA-2012:0987",
      # This advisory contains 3 brew build mappings
      # - 2 non-rpms brew maps, so they should be skipped.
      # - 1 rpm map (but missing product listings cache), so should return empty result
      "RHBA-2014:16398"
    ]

    arches = Arch.all
    # Never query the database because they are cached in the beginning
    ProductListingCache.expects(:find_by_product_version_id_and_brew_build_id).never
    BrewBuild.any_instance.expects(:brew_files).never
    Package.any_instance.expects(:package_restrictions).never
    Arch.expects(:all).times(errata.size).returns(arches)

    errata.each do |errata_id|
      errata = Errata.find_by_advisory(errata_id)
      package_map = {}
      # format the output to simpler version so that it is
      # easy to compare
      errata.get_variants_used_by_rpms.each_pair do |pkg,variants|
        package_map[pkg.name] = variants.map(&:name).sort
      end
      assert_testdata_equal "variants_used_by_rpms_#{errata.id}.json", canonicalize_json(package_map.to_json)
    end

    # make sure the caches are clear when finish
    assert_nil Thread.current[:cached_arches]
    assert_nil Thread.current[:cached_files]
    assert_nil Thread.current[:cached_listings]
    assert_nil Thread.current[:cached_restrictions]
  end

  test "get variants used by an advisory with package restrictions" do
    [
      ["sblim-cim-client2", "6Workstation"],
      ["sblim-cim-client2", "6Workstation-optional"]
    ].each do |package_name, variant_name|
      package = Package.find_by_name(package_name)
      variant = Variant.find_by_name(variant_name)
      PackageRestriction.create!(:package => package, :variant => variant, :push_targets => [])
    end

    # Make sure it will never query the database
    Package.any_instance.expects(:package_restrictions).never

    errata = Errata.find_by_advisory("RHSA-2012:0987")
    package_map = errata.get_variants_used_by_rpms

    # The results should not be emptied
    refute package_map.values.flatten.empty?
    # Output should not contain these variants
    refute package_map.values.flatten.map(&:name).include?("6Workstation")
    refute package_map.values.flatten.map(&:name).include?("6Workstation-optional")
  end

  test "errata batch validation" do
    e = Errata.find(19829)

    # Release batch
    e.batch_id = 6
    refute e.valid?
    assert_equal 'Batch cannot be released', e.errors.full_messages.first

    # Inactive batch
    e.batch_id = 3
    refute e.valid?
    assert_equal 'Batch must be active', e.errors.full_messages.first

    # Different release
    e.batch_id = 4
    refute e.valid?
    assert_equal 'Batch must be for same release', e.errors.full_messages.first

    # This should be OK
    e.batch_id = 2
    assert e.valid?
  end

  test "use batch release date for batch errata" do
    e = Errata.find(19707)
    assert_equal 2, e.batch_id
    batch_release_date = e.batch.release_date

    # If batch is inactive, publish date is default
    e.batch.is_active = false
    assert_equal 'default', e.publish_date_explanation
    assert_not_equal batch_release_date, e.publish_date

    # publish (release) date comes from batch if active
    e.batch.is_active = true
    assert_equal 'batch', e.publish_date_explanation
    assert_equal batch_release_date, e.publish_date

    # Remove from batch, publish date is default
    e.batch_id = nil
    assert_equal 'default', e.publish_date_explanation
    assert_not_equal batch_release_date, e.publish_date
  end

  test "changing release updates batch" do
    e = Errata.find(19829)
    assert_nil e.batch

    # RHEL-7.2.0, supports batching
    release_batching = Release.find(468)
    assert release_batching.enable_batching?

    e.release = release_batching
    e.save!

    # Advisory's batch has been set
    assert_not_nil e.batch

    # RHEL-7.0.Z, does not support batching
    release_non_batching = Release.find(356)
    refute release_non_batching.enable_batching?

    e.release = release_non_batching
    e.save!

    # Advisory's batch has been removed
    assert_nil e.batch
  end

  test "comment for initial batch assignment" do
    e = RHBA.create!(
      :reporter => qa_user,
      :synopsis => 'test 1',
      :product => Product.find_by_short_name('RHEL'),
      :release => Release.find_by_name('RHEL-7.1.Z'),
      :assigned_to => qa_user,
      :content => Content.new(
        :topic => 'test',
        :description => 'test',
        :solution => 'fix it'
      )
    )

    assert_match /Advisory batch set to/, e.comments.last.text
  end

  test "newly created errata has content_types initialised" do
    e = RHBA.create!(
      :reporter => qa_user,
      :synopsis => 'test 1',
      :product => Product.find_by_short_name('RHEL'),
      :release => Release.find_by_name('RHEL-7.1.Z'),
      :assigned_to => qa_user,
      :content => Content.new(
        :topic => 'test',
        :description => 'test',
        :solution => 'fix it'
      )
    )

    assert_equal [].to_yaml, e.read_attribute(:content_types)
  end

  test "has_docker? returns true only if advisory has docker files" do

    # This advisory has docker image files
    e = Errata.find(21100)
    assert e.has_docker?
    assert_equal 1, e.build_mappings.count

    # Update mapping so the build's .ks files are selected instead
    mapping = e.build_mappings.first
    mapping.update_attribute(:brew_archive_type_id, 38)
    e.reload

    # No docker images are now attached to advisory
    refute e.has_docker?
  end

  test 'duplicate build_mappings not returned' do
    e = Errata.find(16396)
    assert_equal 3, e.build_mappings.count
    assert_equal 3, ErrataBrewMapping.where(:errata_id => e, :current => 1).count

    e.build_mappings.each do |m|
      ErrataBrewMapping.create(
        :errata_id => m.errata_id,
        :brew_build_id => m.brew_build_id,
        :product_version_id => m.product_version_id,
        :package_id => m.package_id,
        :current => 1,
        :spin_version => m.spin_version,
        :brew_archive_type_id => m.brew_archive_type_id
      )
    end

    e.reload
    assert_equal 3, e.build_mappings.count
    assert_equal 6, ErrataBrewMapping.where(:errata_id => e, :current => 1).count
  end

  test 'duplicate current_files not returned' do
    e = Errata.find(18916)
    assert_equal 3, e.current_files.count
    assert_equal 6, ErrataFile.where(:errata_id => e, :current => 1).count
  end

  test 'current_files and variants for legacy advisory' do
    e = Errata.find(18916)
    assert e.current_files.any?
    assert e.current_files.first.is_a?(ErrataFile)
    assert e.variants.any?
    assert e.variants.first.is_a?(Variant)
  end

  test 'current_files and variants for pdc advisory' do
    e = Errata.find(21131)
    assert e.current_files.any?
    assert e.current_files.first.is_a?(PdcErrataFile)
    assert e.variants.any?
    assert e.variants.first.is_a?(PdcVariant)
  end

  test 'empty product listing cache still has builds' do
    Brew.any_instance.stubs(:getProductListings => {})
    e = Errata.find 23101
    builds_by_pv = e.build_files_by_nvr_variant_arch
    assert_equal 1, builds_by_pv.keys.length
    builds = builds_by_pv['RHEL-6.7.Z-Supplementary']
    assert_equal 1, builds.length
    assert builds[0].has_key?("chromium-browser-49.0.2623.108-1.el6")
    assert builds[0]["chromium-browser-49.0.2623.108-1.el6"].empty?
  end

  test 'setting text_only flag clears content_types' do
    e = Errata.find 20836
    assert_equal ['rpm'], e.content_types
    refute e.text_only?

    e.update_attribute(:text_only, true)
    assert e.text_only?
    assert_equal [], e.content_types

    e.update_attribute(:text_only, false)
    refute e.text_only?
    assert_equal ['rpm'], e.content_types
  end
end
