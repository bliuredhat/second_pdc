require 'test_helper'

class ErrataControllerTest < ActionController::TestCase

  test 'can display cpe list' do
    auth_as devel_user
    pdc_advisory = Errata.find(21131)
    assert pdc_advisory.is_pdc?, "#{pdc_advisory} is not PDC"

    VCR.use_cassette('pdc_rhsa_21131_cpe_list') do
      get :cpe_list, id: pdc_advisory.id, format: 'js'
    end

    assert_response :success, response.body
    assert_match %r{ceph-2.1-updates@rhel-7/MON, ceph-2.1-updates@rhel-7/OSD},
                 response.body
  end
end
