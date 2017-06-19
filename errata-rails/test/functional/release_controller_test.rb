require 'test_helper'

class ReleaseControllerTest < ActionController::TestCase
  setup do
    auth_as releng_user
  end

  test "index" do
    get :index
    assert_redirected_to :controller => :release, :action => :active_releases
  end

  test "list" do
    get :list
    assert_redirected_to :controller => :release, :action => :active_releases
  end

  test "active releases" do
    get :active_releases
    assert_response :success
  end

  test "can add and remove product versions" do
    auth_as admin_user
    [ Release.find_by_name('ASYNC').id, QuarterlyUpdate.last.id ].each do |release_id|

      # Can set product versions
      post :update, :id=>release_id, :release => {:product_version_ids => [227, 228]}
      assert_redirected_to :action => :show, :id => release_id
      assert_equal [227, 228], Release.find(release_id).product_versions.map(&:id)

      # Can also clear them (didn't work prior to bz 1017142)
      post :update, :id=>release_id, :release => {}
      assert_redirected_to :action => :show, :id => release_id
      assert Release.find(release_id).product_versions.empty?
    end
  end

  test "create new release" do
    auth_as admin_user
    release_name = "RHEL-100"
    release_type = "QuarterlyUpdate"
    release_blks = ["rhel-6.1.0", "devel_ack", "qa_ack", "pm_ack"]
    release_desc = "Red Hat Enterprise Linux 100"

    params = {
      :type => release_type,
      :release => {
        :name => release_name,
        :blocker_flags => release_blks.first,
        :ship_date => 2.days.from_now,
        :description => release_desc,
      },
    }

    assert_difference("Release.count", 1) do
      post :create, params
    end

    actual = Release.last

    assert_response :redirect
    assert_match(/Release was successfully created/, flash[:notice])

    expected = {
      :type => release_type,
      :name => release_name,
      :blocker_flags => release_blks,
      :description => release_desc,
    }

    expected.each_pair do |attr, val|
      if val.kind_of?(Array)
        assert_array_equal val.sort, actual.send(attr).sort
      else
        assert_equal val, actual.send(attr)
      end
    end
  end

  test "validation errors are shown for invalid input" do
    auth_as admin_user
    release_type = "Async"
    release_blks = ["rhel-6.1.0", "devel_ack", "qa_ack", "pm_ack"]

    params = {
      :type => release_type,
      :release => {
        :blocker_flags => release_blks.first,
        :ship_date => 2.days.from_now,
      },
    }
    post :create, params
    assert_response :success
    assert_match /\d+ errors prohibited this \w+ from being saved/, response.body
  end

  test "validation errors when check is_pdc and select non-pdc product" do
    auth_as admin_user
    release_name = "RHEL-100"
    release_type = "QuarterlyUpdate"
    release_blks = ["rhel-6.1.0", "devel_ack", "qa_ack", "pm_ack"]
    release_desc = "Red Hat Enterprise Linux 100"

    params = {
      :type => release_type,
      :release => {
        :name => release_name,
        :blocker_flags => release_blks.first,
        :ship_date => 2.days.from_now,
        :description => release_desc,
        :product_id => 82,
        :is_pdc => true
      },
    }
    post :create, params
    assert_response :success
    assert_match /2 errors prohibited this .* from/, response.body
  end

  test "validation errors the product without an associated PDC product " do
    auth_as admin_user
    release_name = "RHEL-100"
    release_type = "QuarterlyUpdate"
    release_blks = ["rhel-6.1.0", "devel_ack", "qa_ack", "pm_ack"]
    release_desc = "Red Hat Enterprise Linux 100"

    params = {
      :type => release_type,
      :release => {
        :name => release_name,
        :blocker_flags => release_blks.first,
        :ship_date => 2.days.from_now,
        :description => release_desc,
        :product_id => 224,
        :is_pdc => true
      },
    }
    post :create, params
    assert_response :success
    assert_match /1 error prohibited this .* from/, response.body
    assert_match /Please make sure that the ET Product has been mapped to a PDC Product/, response.body
  end
end