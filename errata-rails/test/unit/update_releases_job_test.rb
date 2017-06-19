require 'test_helper'

class UpdateReleasesJobTest < ActiveSupport::TestCase
  test 'job updates ACL successfully' do
    job = Bugzilla::UpdateReleasesJob.new

    r = Release.find_by_name('RHEL-5.7.0')
    old_acl = r.approved_components.map(&:name)

    assert old_acl.include?('xen')
    assert old_acl.include?('openssl')
    assert old_acl.include?('yum-utils')
    refute old_acl.include?('qpid-qmf')

    mock_acl = old_acl.to_set.add('qpid-qmf') - %w(xen openssl)

    # approved_component_for will be called for each of
    #   rhel-6.1.0, rhel-7.0.0 rhel-7.2.0, rhel-6.8.0
    # that we ignore as we are interested in only r.release_blocker_flag

    Bugzilla::TestRpc.any_instance
      .expects(:approved_components_for)
      .with(Not equals(r.release_blocker_flag))
      .at_least(4)
      .returns(nil)

    Bugzilla::TestRpc.any_instance
      .expects(:approved_components_for)
      .with(r.release_blocker_flag)
      .once
      .returns(mock_acl)

    job.perform
    r.reload

    new_acl = r.approved_components.map(&:name)
    added = (new_acl - old_acl).sort
    removed = (old_acl - new_acl).sort
    assert_equal %w{qpid-qmf}, added
    assert_equal %w{openssl xen}, removed
  end
end

