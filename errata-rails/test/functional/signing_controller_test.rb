require 'test_helper'

class SigningControllerTest < ActionController::TestCase
  setup do
    auth_as signer_user
  end

  test 'remove needsign flag' do
    e = Errata.find(11112)
    e.sign_requested = 1
    e.save!

    assert_equal 1, e.sign_requested

    post :remove_needsign_flag, :id => e
    assert_response :success, response.body
    e.reload
    assert_equal 0, e.sign_requested
  end

  test 'unsigned_builds only considers RPMs in advisory with mixed content' do
    # docker advisory has RPMs and non-RPMs
    e = Errata.find(16396)

    get :unsigned_builds, :id => e, :format => :json
    assert_response :success, response.body

    obj = JSON.load(response.body)
    assert obj.include?('rhel-server-docker-7.0-22')
    rpm_basenames = obj['rhel-server-docker-7.0-22']['rpms'].map{|x| File.basename(x)}
    assert_equal %w[rhel-server-docker-7.0-22.src.rpm rhel-server-docker-7.0-22.noarch.rpm].sort, rpm_basenames.sort
  end

  test 'unsigned_builds returns no data for advisory with only non-RPM content' do
    # jboss picketlink advisory has non-RPMs only
    e = Errata.find(16397)

    get :unsigned_builds, :id => e, :format => :json
    assert_response :success, response.body

    obj = JSON.load(response.body)
    assert_equal( {}, obj)
  end

  test 'can mark_as_signed build with mixed content' do
    # docker advisory has RPMs and non-RPMs
    e = Errata.find(16396)

    nvr = 'rhel-server-docker-7.0-22'
    bb = BrewBuild.find_by_nvr!(nvr)
    BrewBuild.expects(:find_by_nvr).with(nvr).returns(bb)
    bb.expects(:mark_as_signed).once

    assert_difference('ActionMailer::Base.deliveries.length', 1) do
      post :mark_as_signed, :id => e, :brew_build => nvr, :sig_key => 'fd431d51'
    end
    assert_response :success, response.body
    assert_equal 'ok', response.body

    comment = e.comments.last
    assert comment.is_a?(BuildSignedComment)
    assert_match /signed with key/, comment.text

    mail = ActionMailer::Base.deliveries.last
    assert_equal 'BUILD-SIGNED', mail['X-ErrataTool-Action'].value
  end

  test 'cannot mark_as_signed build with no RPM content' do
    # jboss picketlink advisory has non-RPMs only
    e = Errata.find(16397)

    nvr = 'org.picketbox-picketbox-infinispan-4.0.9.Final-1'
    BrewBuild.any_instance.expects(:mark_as_signed).never

    post :mark_as_signed, :id => e, :brew_build => nvr, :sig_key => 'fd431d51'
    assert_response :not_found, response.body
    assert_match %r{\bno RPMs in mapping\b}, response.body
  end
end
