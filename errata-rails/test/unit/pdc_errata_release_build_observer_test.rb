require 'test_helper'

class PdcErrataReleaseBuildObserverTest < ActiveSupport::TestCase
  setup do
    @mapping = PdcErrataReleaseBuild.find(3)
  end

  test 'expected observers are bound' do
    expected_observers = %w(BuildCcObserver
                            BuildCommentObserver
                            BuildMessagingObserver
                            CovscanCreateObserver
                            RpmdiffObsoletionObserver)

    bound_observers = PdcErrataReleaseBuild.observer_instances.map { |obj| obj.class.name }.sort
    assert_equal expected_observers, bound_observers
  end

  test 'build cc observer pdc' do
    user = User.find_by_login_name "jorris@redhat.com"
    assert user.enabled?
    assert user.receives_mail?
    assert user.in_role?('errata')

    assert @mapping.errata.cc_list.where(:who_id => user).empty?

    with_current_user(user) do
      PdcErrataReleaseBuild.notify_observers :after_create, @mapping
    end

    errata = Errata.find @mapping.errata.id
    assert errata.cc_list.where(:who_id => user).present?
  end

  test 'build comment observer pdc' do
    VCR.use_cassettes_for(:ceph21) do
      @mapping.obsolete!
      PdcErrataReleaseBuild.notify_observers :after_commit, @mapping
      errata = Errata.find @mapping.errata
      comment = errata.comments.last
      assert_equal "Removed build ceph-10.2.3-17.el7cp (for ceph-2.1-updates@rhel-7) from advisory.",
      comment.text
    end
  end

  test 'build messaging observer pdc' do
    BuildMessagingObserver.any_instance.expects(:send_build_removed_message).once
    VCR.use_cassettes_for(:ceph21) do
      @mapping.obsolete!
      PdcErrataReleaseBuild.notify_observers :after_commit, @mapping
    end
  end

  test 'covscan create observer pdc' do
    @mapping.errata.stubs(:requires_external_test?).returns(true)
    CovscanCreateObserver.expects(:create_covscan_run).once
    VCR.use_cassettes_for(:ceph21) do
      PdcErrataReleaseBuild.notify_observers :after_create, @mapping
    end
  end

  test 'rpmdiff run observer pdc' do
    errata = @mapping.errata
    assert_equal 0, errata.rpmdiff_runs.current.count
    VCR.use_cassette 'rpmdiff_run_observer_pdc' do
      RpmdiffRun.schedule_runs errata
      assert_equal 1, errata.rpmdiff_runs.current.count

      @mapping.obsolete!
      PdcErrataReleaseBuild.notify_observers :after_commit, @mapping
      errata = Errata.find @mapping.errata
      assert_equal 0, errata.rpmdiff_runs.current.count
    end
  end

end
