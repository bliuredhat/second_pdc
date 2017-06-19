require 'test_helper'

class PdcVariantTest < ActiveSupport::TestCase

  setup do
    VCR.insert_cassette fixture_name
    @pdc_variant_pdc_id = 'ceph-1.3@rhel-7/Calamari'
  end

  teardown do
    VCR.eject_cassette
  end

  def pdc_variant
    PdcVariant.get(@pdc_variant_pdc_id)
  end

  test "can create a pdc variant" do
    assert pdc_variant
    assert pdc_variant.is_a?(PdcVariant)
    assert_equal @pdc_variant_pdc_id, pdc_variant.pdc_id
  end

  test "pdc variant has supported push types" do
    pdc_variant = PdcVariant.get("ceph-2.1-updates@rhel-7/MON")
    assert_equal [:rhn_stage, :rhn_live, :ftp, :cdn_stage, :cdn, :altsrc], pdc_variant.supported_push_types
  end

  test "pdc variant has some data" do
    assert_equal "Calamari", pdc_variant.name
    assert_equal "ceph-1.3@rhel-7", pdc_variant.release.release_id
    assert_equal "Calamari", pdc_variant.uid
  end

  test "pdc variant has some ftp.redhat.com repos" do
     VCR.use_cassettes_for(:pdc_ceph21) do
      %w[MON OSD].each do |variant_uid|
        pdc_variant = PdcVariant.get("ceph-2.1-updates@rhel-7/#{variant_uid}")
        {
          'source' => '/ftp/pub/redhat/linux/enterprise/7Server/en/RHCEPH/SRPMS',
        }.each_pair do |content_category, expected_path|
          repos = pdc_variant.ftp_path_repos(:content_category=>content_category)
          assert_equal 1, repos.length, "Expected one ftp path repo!"
          assert_equal expected_path, repos.first.name, "Unexpected ftp path for #{content_category}: #{repos.first.name}!"
        end
      end
    end
  end
end
