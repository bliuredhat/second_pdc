require 'test_helper'

class PdcReleaseTest < ActiveSupport::TestCase

  setup do
    VCR.insert_cassette fixture_name
    @pdc_release_pdc_id = 'rhel-7.0'
  end

  teardown do
    VCR.eject_cassette
  end

  def pdc_release
    PdcRelease.get(@pdc_release_pdc_id)
  end

  test "can create a pdc release" do
    assert pdc_release
    assert pdc_release.is_a?(PdcRelease)
    assert_equal @pdc_release_pdc_id, pdc_release.pdc_id
  end

  test "pdc release has some data" do
    assert_equal "Red Hat Enterprise Linux", pdc_release.name
  end

  test "pdc release has some variants" do
    variants = pdc_release.variants
    assert variants.first.is_a?(::PDC::V1::ReleaseVariant)
    assert_equal "Client", variants.sort_by(&:name).first.name
  end

  test "pdc release has some PdcVariant records" do
    VCR.use_cassettes_for(:pdc_ceph21) do
      pr = PdcRelease.get('ceph-2.1-updates@rhel-7')
      vs = pr.pdc_variants
      assert_equal 2, vs.count
      assert vs.all?{ |v| v.is_a?(PdcVariant) }
    end
  end

  test "pdc releases have push targets" do
    # Test case is based on Hardcode setting, will be changed in future.
    push_targets = pdc_release.push_targets
    assert push_targets
    count = push_targets.count
    assert_equal 6, count
  end

  test "pdc release variants count" do
    count = pdc_release.variants.count
    assert_equal 11, count
  end

  test "can call map on release variants" do
    variants = pdc_release.variants
    variants.map(&:name)
  end

  test "pdc release is active" do
    assert_true pdc_release.active?
  end

  test "pdc release with valid tag" do
    assert_equal ["rhel-7.0","rhel-7.0-candidate"], pdc_release.valid_tags.sort
  end

  test "pdc release without valid tag" do
    pr = PdcRelease.get('ceph-1.3-updates@rhel-7')
    assert_nil pr.brew
    assert_equal [], pr.valid_tags
  end

  test "pdc release has cdn repos" do
    pr = PdcRelease.get('ceph-2.1-updates@rhel-7')
    assert pr.cdn_repos
    assert_equal 18, pr.cdn_repos.count
  end

  test "pdc release has channels" do
    pr = PdcRelease.get('ceph-2.1-updates@rhel-7')
    assert pr.channels
    assert_equal 6, pr.channels.count
  end

  test "pdc variant has cdn repos" do
    v = PdcVariant.get(pdc_id: 'ceph-2.1-updates@rhel-7/Client-Tools')
    assert v.cdn_repos
    assert_equal 3, v.cdn_repos.count
  end

  test "pdc variant has channels" do
    v = PdcVariant.get(pdc_id: 'ceph-2.1-updates@rhel-7/Client-Tools')
    assert v.channels
    assert_equal 1, v.channels.count
  end

  test "pdc release view url" do
    assert_equal 'https://pdc.engineering.redhat.com/release/rhel-7.0/', pdc_release.view_url
  end

  test "rhel_release with base product" do
    pr = PdcRelease.first
    pr.stubs(:product_version => 'ignored', :base_product => 'rhel-6')
    assert_equal 'rhel-6', pr.rhel_release
    assert_equal 6, pr.rhel_release_number
    assert pr.is_at_least_rhel5?

    pr.stubs(:product_version => 'ignored', :base_product => 'rhel-4')
    assert !pr.is_at_least_rhel5?
  end

  test "rhel_release with product version" do
    pr = PdcRelease.first
    pr.stubs(:product_version => 'rhel-7', :base_product => nil)
    assert_equal 'rhel-7', pr.rhel_release
    assert_equal 7, pr.rhel_release_number
  end
end
