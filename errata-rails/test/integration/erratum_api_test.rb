require 'test_helper'

class ErratumApiTest < ActionDispatch::IntegrationTest

  setup do
    auth_as releng_user
    @api = 'api/v1/erratum'
  end

  test "successfully posts new comment" do
    advisory = RHEA.find(11112)

    with_baselines(@api, /add_comment_11112.json$/) do |match|
      post_json "/api/v1/erratum/#{advisory.id}/add_comment",
                {:comment => "Happy comment"}
      formatted_json_response
    end
    advisory.reload
    comment = advisory.comments.last
    assert_equal "Happy comment", comment.text
    assert_equal releng_user, comment.who
  end

  test "adding empty comment results in an error" do
    advisory = RHEA.find(11112)

    assert_no_difference('Comment.count') do
      post_json "/api/v1/erratum/#{advisory.id}/add_comment",
                {:comment => ""}
    end
    assert_response :bad_request
    assert_match %r{\bcan't be blank\b}, response.body, response.body
  end

  test "successfully create a PDC advisory" do
    # make sure product and release in parameters support PDC
    product = Product.find_by_short_name('PDC-PRODUCT')
    assert_true product.supports_pdc?

    release = Release.find_by_name('ReleaseForPDC')
    assert_true release.is_pdc?

    post_data = {:advisory =>
                   {:errata_type => 'PdcRHEA',
                    :security_impact => 'Low',
                    :solution => '2',
                    :description => 'test',
                    :manager_email => 'ship-list@redhat.com',
                    "package_owner_email" => 'mbabej@redhat.com',
                    :synopsis => 'test',
                    :topic => 'test',
                    :text_only => '1',
                    :keywords => 'test',
                    :reference => 'References',
                    :publish_date_override => '2013-11-21',
                    :embargo_date => '2013-11-11',
                    :text_ready => '1'},
                 :product =>  product.short_name,
                 :release => release.name}
    assert_difference('Errata.count') do
      post_json "/api/v1/erratum/", post_data
      assert_equal response.status, 201, 'Failed to create PDC advisory'
    end
  end

  test "error happens when create a PDC advisory with legacy product and release" do
    product = Product.find_by_short_name('RHEL')
    assert_false product.supports_pdc?

    release = Release.find_by_name('RHEL-6.1.0')
    assert_false release.is_pdc?

    post_data = {:advisory =>
                   {:errata_type => 'PdcRHEA',
                    :security_impact => 'Low',
                    :solution => '2',
                    :description => 'test',
                    :manager_email => 'ship-list@redhat.com',
                    "package_owner_email" => 'mbabej@redhat.com',
                    :synopsis => 'test',
                    :topic => 'test',
                    :text_only => '1',
                    :keywords => 'test',
                    :reference => 'References',
                    :publish_date_override => '2013-11-21',
                    :embargo_date => '2013-11-11',
                    :text_ready => '1'},
                 :product =>  product.short_name,
                 :release => release.name}
    assert_no_difference('Errata.count') do
      post_json "/api/v1/erratum/", post_data
      assert_not_equal response.status, 201, 'Failed to prevent illegal PDC advisory from being created'
    end
  end

  test "create a advisory with PDC product and release will generate PDC errata type" do
    product = Product.find_by_short_name('PDC-PRODUCT')
    assert_true product.supports_pdc?

    release = Release.find_by_name('ReleaseForPDC')
    assert_true release.is_pdc?

    post_data = {:advisory =>
                   {:errata_type => 'RHEA',
                    :security_impact => 'Low',
                    :solution => '2',
                    :description => 'test',
                    :manager_email => 'ship-list@redhat.com',
                    "package_owner_email" => 'mbabej@redhat.com',
                    :synopsis => 'test',
                    :topic => 'test',
                    :text_only => '1',
                    :keywords => 'test',
                    :reference => 'References',
                    :publish_date_override => '2013-11-21',
                    :embargo_date => '2013-11-11',
                    :text_ready => '1'},
                 :product =>  product.short_name,
                 :release => release.name}
    assert_difference('PdcRHEA.count') do
      post_json "/api/v1/erratum/", post_data
      assert_equal response.status, 201, 'Failed to create PDC errata type davisory according to release'
    end
  end

  test "create a advisory with legacy product and release will generate legacy errata type" do
    product = Product.find_by_short_name('RHEL')
    assert_false product.supports_pdc?

    release = Release.find_by_name('RHEL-6.1.0')
    assert_false release.is_pdc?

    post_data = {:advisory =>
                   {:errata_type => 'RHEA',
                    :security_impact => 'Low',
                    :solution => '2',
                    :description => 'test',
                    :manager_email => 'ship-list@redhat.com',
                    "package_owner_email" => 'mbabej@redhat.com',
                    :synopsis => 'test',
                    :topic => 'test',
                    :text_only => '1',
                    :keywords => 'test',
                    :reference => 'References',
                    :publish_date_override => '2013-11-21',
                    :embargo_date => '2013-11-11',
                    :text_ready => '1'},
                 :product =>  product.short_name,
                 :release => release.name}
    assert_difference('RHEA.count') do
      post_json "/api/v1/erratum/", post_data
      assert_equal response.status, 201, 'Failed to create legacy errata type davisory by legacy errata type'
    end
  end

  test "update a PDC advisory with errata type will generate PDC errata type" do
    errata_id = PdcRHEA.find(:first).id

    update_data = {:advisory => {:errata_type => 'RHBA'}}
    put_json "/api/v1/erratum/#{errata_id}", update_data
    assert_equal Errata.find(errata_id).errata_type, 'PdcRHBA'
  end

  test "update a legacy advisory with errata type will generate legacy errata type" do
    errata_id = RHEA.find(:first).id

    update_data = {:advisory => {:errata_type => 'RHBA'}}
    put_json "/api/v1/erratum/#{errata_id}", update_data
    assert_equal Errata.find(errata_id).errata_type, 'RHBA'
  end

  test "update a advisory without errata type argument should work" do
    errata_id = PdcRHEA.find(:first).id
    update_data = {:advisory => {:synopsis => 'only change synopsis'}}
    put_json "/api/v1/erratum/#{errata_id}", update_data
    assert_equal response.status, 204, 'Update advisory without errata type failed'

    errata_id = RHEA.find(:first).id
    update_data = {:advisory => {:synopsis => 'only change synopsis'}}
    put_json "/api/v1/erratum/#{errata_id}", update_data
    assert_equal response.status, 204, 'Update advisory without errata type failed'
  end
end
