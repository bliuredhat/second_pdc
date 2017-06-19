require 'test_helper'

class RpmdiffRunsTest < ActiveSupport::TestCase
  test "rpmdiff stats" do
    stats = YAML.load(File.open('test/data/rpmdiff_stats.yml'))
    # Test harness default advisory should be empty
    stats[rhba_async.id] = {500 => 1}
    Errata.all.each do |e|
      # Skip over advisories created within the testing transaction.
      # only interested in in test data results. Otherwise will fail
      # due to a lack of test data.
      next unless stats.has_key?(e.id)
      assert_equal stats[e.id], e.rpmdiff_stats, "Errata #{e.id} RPMDiff stats do not match"
    end
  end

  test "verify current good runs" do
    runs = RpmdiffRun.where('last_good_run_id is not null')
    runs.each do |r|
      assert [0,2].include?(r.last_good_run.overall_score)
    end
  end

  test "verify rescheduing last good run set" do
    oldrun = RpmdiffRun.where('overall_score in (0,2)').last
    newrun = oldrun.reschedule
    assert_equal oldrun.last_good_run, newrun.last_good_run
  end

  test "Verify incremental build comparision" do
    run = RpmdiffRun.find 50224
    # Ensure we have the baseline we think we do
    assert_equal 'tomcat6-6.0.24-30.el6', run.brew_build.nvr
    new_build = BrewBuild.find_by_nvr 'tomcat6-6.0.24-33.el6'
    e = run.errata
    assert_equal 1, e.build_mappings.length
    oldmap = e.build_mappings.first
    ActiveRecord::Base.transaction do
      oldmap.obsolete!
      ErrataBrewMapping.create!(:product_version => oldmap.product_version,
                                :errata => e,
                                :brew_build => new_build,
                                :package => new_build.package)
      RpmdiffRun.schedule_runs(e)
    end
    e = Errata.find e.id
    new_run = e.rpmdiff_runs.last
    assert_equal 500, new_run.overall_score
    assert_equal run, new_run.last_good_run
    assert_equal new_run.old_version, run.new_version
  end

  test "rpmdiff runs validation" do
    errata = Errata.find(7517)
    assert_equal 0, errata.rpmdiff_runs.count, "Fixture issue."

    # should return false if no jobs are scheduled
    refute errata.rpmdiff_finished?

    RpmdiffRun.schedule_runs(errata)

    errata_builds = errata.build_mappings.for_rpms.map(&:brew_build_id).uniq
    scheduled_builds = errata.rpmdiff_runs.map(&:brew_build_id).uniq

    assert_array_equal errata_builds, scheduled_builds, "Not all brew builds are scheduled."

    # should return false because no jobs are run yet
    refute errata.rpmdiff_finished?

    pass_rpmdiff_runs(errata)

    # return true now
    assert errata.rpmdiff_finished?

    # try delete a rpmdiff job to make the errata block again.
    errata.rpmdiff_runs.where(:brew_build_id => errata_builds.first).delete_all

    # should return false because every build must have a rpmdiff run.
    refute errata.rpmdiff_finished?
  end

  test "rpmdiff runs validation with pdc advisory" do
    errata = Errata.find(21131)
    assert errata.is_pdc?

    errata_builds = errata.build_mappings.for_rpms.map(&:brew_build_id).uniq

    # try to delete the rpmdiff job which is loaded from fixture.
    errata.rpmdiff_runs.where(:brew_build_id => errata_builds.first).delete_all
    assert_equal 0, errata.rpmdiff_runs.count, "Fixture issue."

    # should return false if no jobs are scheduled
    refute errata.rpmdiff_finished?

    VCR.use_cassette('pdc_advisory_rpmdiff_test') do
      RpmdiffRun.schedule_runs(errata)
    end

    scheduled_builds = errata.rpmdiff_runs.map(&:brew_build_id).uniq

    assert_array_equal errata_builds, scheduled_builds, "Not all brew builds are scheduled."

    # should return false because no jobs are run yet
    refute errata.rpmdiff_finished?

    pass_rpmdiff_runs(errata)

    # return true now
    assert errata.rpmdiff_finished?

    # try delete a rpmdiff job to make the errata block again.
    errata.rpmdiff_runs.where(:brew_build_id => errata_builds.first).delete_all

    # should return false because every build must have a rpmdiff run.
    refute errata.rpmdiff_finished?
  end

  # https://bugzilla.redhat.com/show_bug.cgi?id=1443808
  test "obsoleting PdcErrataReleaseBuild also obsoletes associated RpmdiffRun" do
   VCR.use_cassettes_for(:pdc_ceph21) do
    errata = Errata.find(21131)
    assert errata.is_pdc?
    assert_equal 1, errata.build_mappings.count

    assert_equal 1, errata.rpmdiff_runs.current.count
    run = errata.rpmdiff_runs.current.first
    map = errata.build_mappings.first
    map.obsolete!

    errata = Errata.find(21131)
    assert_equal 0, errata.rpmdiff_runs.current.count
    run = RpmdiffRun.find run.id
    assert run.obsolete?, "Run not marked as obsolete!"
   end
  end

  test "rpmdiff released package works for pdc" do
   VCR.use_cassettes_for(:pdc_ceph21) do
    errata = Errata.find(21131)
    assert errata.is_pdc?
    assert_equal 1, errata.build_mappings.count
    old_map = errata.build_mappings.first
    assert_equal 'ceph-10.2.3-17.el7cp', old_map.brew_build.nvr
    old_map.obsolete!

    RpmdiffRun.invalidate_all_runs(errata)

    PdcErrataReleaseBuild.create!(pdc_errata_release: old_map.pdc_errata_release,
      brew_build: BrewBuild.find_by_nvr('ceph-10.2.5-26.el7cp'),
      skip_rpm_version_validation: true)

    PdcReleasedPackage.create!(pdc_release: old_map.pdc_release,
                               pdc_variant: PdcVariant.first,
                               brew_build: old_map.brew_build,
                               package: old_map.package,
                               full_path: old_map.brew_build.brew_rpms.first.file_path,
                               arch: Arch.find_by_name('i386'))

    errata = Errata.find(21131)
    assert_equal 1, errata.build_mappings.count
    RpmdiffRun.any_instance.stubs(:brew_build_has_srpm).returns(true)

    VCR.use_cassette('pdc_advisory_rpmdiff_test') do
      RpmdiffRun.schedule_runs(errata)
    end
    run = errata.rpmdiff_runs.current.first
    assert_equal '10.2.3-17.el7cp', run.old_version
   end
  end

  test "rpmdiff scheduling with warnings" do
    errata = Errata.find(7517)

    map_with_rpm = ErrataBrewMapping.for_rpms.first
    map_without_rpm = ErrataBrewMapping.for_nonrpms.first
    map_without_variant = ErrataBrewMapping.for_rpms.first
    map_without_variant.stubs(:rhel_variants).returns([])
    ErrataBrewMapping.stubs(:for_rpms).returns([map_with_rpm, map_without_rpm, map_without_variant])

    # make sure the warnings are also logged.
    Rails.logger.expects(:error).twice

    errors = []
    assert_difference('RpmdiffRun.count', 1) do
      errors = RpmdiffRun.schedule_runs(errata)
    end

    assert_equal 2, errors.size
    assert errors.include?("Validation failed: Can't schedule RPMDiff run for 'org.picketbox-picketbox-infinispan-4.0.9.Final-1' because this brew build doesn't contain SRPM.")
    assert errors.include?("Validation failed: Variant can't be blank, Can't schedule RPMDiff run because there is no rhel variant for RHEL-4 release.")
  end

  def build_adder(errata)
    lambda do |build,pvs|
      ActiveRecord::Base.transaction do
        pvs = Array.wrap(pvs)
        brew = Brew.get_connection
        pvs.each do |pv|
          # Obsoleting the old builds is supposed to happen just
          # before adding a new build, but it's not enforced in a
          # callback. Have to trigger that ourselves.
          brew.discard_old_package(errata, pv, build.package)
        end

        pvs.each do |pv|
          ErrataBrewMapping.create!(
            :brew_build => build,
            :product_version => pv,
            :errata => errata,
            :package => build.package,
            :brew_archive_type => nil)
        end

        # Ensure rpmdiff runs are scheduled (normally happens
        # automatically when adding builds via UI)
        RpmdiffRun.schedule_runs(errata)
      end
    end
  end

  # Bug 1192813.
  # Scheduler was wrongly using a non-ppc64le build as
  # the baseline for a comparison against a ppc64le build.
  test 'rpmdiff must not pick old version from incompatible pv' do
    e = Errata.find(19707)
    assert_equal 0, e.build_mappings.length, 'fixture problem: expected no builds'

    get_rpmdiff_runs = lambda do
      e.reload.rpmdiff_runs.order('run_id ASC').map{|rr|
        [('OBSOLETE' if rr.obsolete?), rr.package.name, rr.old_version,
         rr.new_version].compact.join(' - ')
      }
    end

    add_build = build_adder(e)

    pvA = ProductVersion.find_by_name!('RHEL-7.1.Z-Supplementary')
    pvB = ProductVersion.find_by_name!('RHEL-LE-7.1.Z-Supplementary')

    buildA = BrewBuild.find_by_nvr!('sssd-1.12.2-58.el7')
    buildB = BrewBuild.find_by_nvr!('sssd-1.12.2-58.ael7b')

    # 1) add build to product version A
    add_build.call(buildA, pvA)

    # This should have scheduled one rpmdiff run, for this package
    assert_equal ['sssd - NEW_PACKAGE - 1.12.2-58.el7'], get_rpmdiff_runs.call()

    # 2) Wait for rpmdiff to pass (or waive it - no difference to this bug)
    e.rpmdiff_runs.first.update_attribute(:overall_score, 1)

    # 3) add build to product version B
    add_build.call(buildB, pvB)

    # This should have scheduled another rpmdiff run from OLD_PACKAGE.
    # (Prior to bug fix, it was instead scheduling from the el7 build above)
    assert_equal [
      'sssd - NEW_PACKAGE - 1.12.2-58.el7',
      'sssd - NEW_PACKAGE - 1.12.2-58.ael7b',
    ], get_rpmdiff_runs.call()
  end

  # Bug 1189191.
  # Adding identical build to multiple PV can cause things to go wrong
  test 'reuses earlier PV when adding newer build to multiple PV' do
    # don't care about build tags here
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)

    e = Errata.find(19401)

    build = BrewBuild.find_by_nvr!('sssd-1.12.2-56.el7')
    build_updated = BrewBuild.find_by_nvr!('sssd-1.12.2-58.el7')

    pvA = ProductVersion.find_by_name!('RHEL-7.1.Z')
    pvB = ProductVersion.find_by_name!('RHEL-LE-7.1.Z')

    add_build = build_adder(e)
    get_rpmdiff_runs = lambda do
      e.reload.rpmdiff_runs.order('run_id asc').current.map{|rr|
        "#{rr.variant} - #{rr.old_version} => #{rr.new_version}"
      }
    end

    assert_equal 0, e.rpmdiff_runs.length,
      'fixture problem: expected no rpmdiff runs'

    # 1) user adds build to pvB and then pvA, in that order
    add_build.call(build, pvB)
    add_build.call(build, pvA)

    # We expect only one rpmdiff run, and scheduled against a variant
    # from pvB since that was added first.
    assert_equal ['7Server-LE-7.1.Z - NEW_PACKAGE => 1.12.2-56.el7'],
      get_rpmdiff_runs.call()

    run = e.rpmdiff_runs.first

    # 2) rpmdiff run succeeds / is waived
    run.update_attribute(:overall_score, 1)

    # 3) user adds updated build to both pvA and pvB together
    add_build.call(build_updated, [pvA, pvB])

    # 4) ET scheduled another run.
    # Although it could have picked either pvA or pvB for the
    # scheduling, it should have preferred pvB since that's the one it
    # used earlier.
    assert_equal [
      "7Server-LE-7.1.Z - NEW_PACKAGE => 1.12.2-56.el7",
      "7Server-LE-7.1.Z - 1.12.2-56.el7 => 1.12.2-58.el7",
    ], get_rpmdiff_runs.call()
  end

 test 'same build on multiple PV obsoletes non-passed run as expected' do
    # similar to the previous test, but this time the rpmdiff run hasn't passed.

    # don't care about build tags here
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)

    e = Errata.find(19401)

    build = BrewBuild.find_by_nvr!('sssd-1.12.2-56.el7')
    build_updated = BrewBuild.find_by_nvr!('sssd-1.12.2-58.el7')

    pvA = ProductVersion.find_by_name!('RHEL-7.1.Z')
    pvB = ProductVersion.find_by_name!('RHEL-LE-7.1.Z')

    add_build = build_adder(e)
    get_rpmdiff_runs = lambda do
      e.reload.rpmdiff_runs.order('run_id asc').current.map{|rr|
        "#{rr.variant} - #{rr.old_version} => #{rr.new_version}"
      }
    end

    assert_equal 0, e.rpmdiff_runs.length,
      'fixture problem: expected no rpmdiff runs'

    # 1) user adds build to pvB and then pvA, in that order
    add_build.call(build, pvB)
    add_build.call(build, pvA)

    # We expect only one rpmdiff run, and scheduled against a variant
    # from pvB since that was added first.
    assert_equal ['7Server-LE-7.1.Z - NEW_PACKAGE => 1.12.2-56.el7'],
      get_rpmdiff_runs.call()

    run = e.rpmdiff_runs.first

    # 2) rpmdiff run fails
    run.update_attribute(:overall_score, 3)

    # 3) user adds updated build to both pvA and pvB together
    add_build.call(build_updated, [pvA, pvB])

    # 4) ET scheduled another run.  Since the earlier rpmdiff run
    # didn't succeed, that run should have been obsoleted and not used
    # as a baseline for the new run.
    assert_equal [
      "7Server-7.1.Z - NEW_PACKAGE => 1.12.2-58.el7",
    ], get_rpmdiff_runs.call()
    assert run.reload.obsolete?
  end

  test 'adding same build to multiple PV in opposite order' do
    # Similar to previous tests but a more complicated scenario, where
    # a user adds one build to multiple PV in a different order on
    # each time.

    # don't care about build tags here
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)

    e = Errata.find(19401)

    build = BrewBuild.find_by_nvr!('sssd-1.12.2-56.el7')
    build_updated = BrewBuild.find_by_nvr!('sssd-1.12.2-58.el7')

    pvA = ProductVersion.find_by_name!('RHEL-7.1.Z')
    pvB = ProductVersion.find_by_name!('RHEL-LE-7.1.Z')

    add_build = build_adder(e)
    get_rpmdiff_runs = lambda do
      e.reload.rpmdiff_runs.order('run_id asc').current.map{|rr|
        "#{rr.variant} - #{rr.old_version} => #{rr.new_version}"
      }
    end

    assert_equal 0, e.rpmdiff_runs.length,
      'fixture problem: expected no rpmdiff runs'

    # 1) user adds build to pvA and then pvB, in that order
    add_build.call(build, pvA)
    add_build.call(build, pvB)

    # We expect only one rpmdiff run, and scheduled against a variant
    # from pvA since that was added first.
    assert_equal ['7Server-7.1.Z - NEW_PACKAGE => 1.12.2-56.el7'],
      get_rpmdiff_runs.call()

    run = e.rpmdiff_runs.first

    # 2) rpmdiff run succeeds / is waived
    run.update_attribute(:overall_score, 1)

    # 3) user adds updated build to pvB only
    add_build.call(build_updated, pvB)

    # 4) ET scheduled another run.
    # At this point, it had to make another run _without_ using the
    # previous pvA test as the baseline, because it can't assume pvA
    # and pvB are compatible.
    assert_equal [
      "7Server-7.1.Z - NEW_PACKAGE => 1.12.2-56.el7",
      "7Server-LE-7.1.Z - NEW_PACKAGE => 1.12.2-58.el7",
    ], get_rpmdiff_runs.call()

    # this run is expected to be replaced later
    replaced_run = e.rpmdiff_runs.order('run_id asc').last
    refute replaced_run.obsolete?

    # 5) user adds updated build to pvA
    latest_comment = e.comments.order('id desc').first.id
    add_build.call(build_updated, pvA)

    # 6) ET scheduled another run.
    #
    # At this point, the user has added updated_build to two product
    # versions, so ET now can assume the product versions are
    # "compatible" for the purpose of rpmdiff.  It decided that the
    # rpmdiff run for build_updated in pvA is better than the one from
    # pvB, since it's from a closer baseline, so it obsoleted the pvB
    # run.
    assert_equal [
      "7Server-7.1.Z - NEW_PACKAGE => 1.12.2-56.el7",
      "7Server-7.1.Z - 1.12.2-56.el7 => 1.12.2-58.el7",
    ], get_rpmdiff_runs.call()
    assert replaced_run.reload.obsolete?

    replacement_run = e.rpmdiff_runs.current.order('run_id asc').last

    # This should also have generated a comment.
    # (There are likely to be multiple comments, try to pick the relevant one)
    comments = e.reload.comments.where('id > ?', latest_comment)
    comments = comments.select{|c| c.text =~ /rpmdiff/i}

    assert_equal ['RpmdiffComment'], comments.map(&:type).uniq
    assert_equal [<<-"eos"], comments.map(&:text)
Due to a change in baseline or variant, the following RPMDiff run has been replaced:

  Run #{replaced_run.id} [sssd new_package => 1.12.2-58.el7] was replaced by run #{replacement_run.id} [sssd 1.12.2-56.el7 => 1.12.2-58.el7]
eos
  end
end
