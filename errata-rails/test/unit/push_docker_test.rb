require 'test_helper'

class PushDockerTest < ActiveSupport::TestCase

  test "cannot push with unmapped docker files" do
    e = Errata.find(21100)
    assert e.unmapped_docker_files.empty?
    assert e.untagged_docker_files.empty?
    assert e.can_push_cdn_docker?

    # Remove package mapping
    CdnRepoPackage.find(3).destroy
    e.reload

    # Can't push with unmapped docker image file
    assert_array_equal [
      'The following Docker builds are not mapped to any CDN repositories: rhel-server-docker-7.1-3'
    ], e.push_cdn_docker_blockers
  end

  test "cannot push with untagged docker files" do
    e = Errata.find(21100)
    assert e.unmapped_docker_files.empty?
    assert e.untagged_docker_files.empty?
    assert e.can_push_cdn_docker?

    # Remove all repo package tags
    CdnRepoPackage.find(3).cdn_repo_package_tags.delete_all
    e.reload

    # Can't push with untagged docker image file
    assert_array_equal [
      'The following Docker images are untagged in these repositories: rhel-server-docker-7.1-3.x86_64.tar.gz (test_docker_7-1)'
    ], e.push_cdn_docker_blockers
  end

  test "cannot push container with active content errata" do
    e = Errata.find(24604)
    assert e.can_push_cdn_docker?
    e.reload
    e.expects(:has_active_container_errata?).returns(true)

    # This was disabled temporarily as a workaround for METAXOR-541
    #refute e.can_push_cdn_docker?
    assert e.can_push_cdn_docker?
    #assert_equal ['A docker image included in this advisory contains RPM-based advisories that have not yet been shipped'], e.push_cdn_docker_blockers
  end

end
