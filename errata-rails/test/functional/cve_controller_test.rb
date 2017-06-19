require 'test_helper'

class CveControllerTest < ActionController::TestCase
  # Help rails find the controller
  tests Noauth::CveController

  test "json cve lists" do
    auth_as secalert_user

    # Pick some, doesn't matter
    test_erratas = RHSA.shipped_live.values_at(0, -2, -1)

    test_erratas.each do |errata|
      assert errata.content.cve.present?

      # Fetches just one
      get :list, :id=>errata.id.to_s, :format=>:json
      check_response_data([errata])
    end

    # Fetches just the ids specified
    get :list, :id=>test_erratas.map{|e|e.id.to_s}.join(","), :format=>:json
    check_response_data(test_erratas)

    # Fetches all all of them, but response still should contain our test erratas
    get :list, :format=>:json
    check_response_data(test_erratas)
  end

  test "fetch one cve" do
    auth_as secalert_user

    errata = Errata.find(19435)
    get :show, :id => errata.id, :format => :json

    assert_response :success
    response_data = ActiveSupport::JSON.decode(response.body)
    %w[cve advisory].each do |field|
      assert response_data.has_key?(field), "Expected '#{field}' to be present in JSON response"
    end
  end

  test 'cve list json baseline test' do
    with_baselines('cve', %r{list.json}) do |file|
      get :list, :format => :json
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  def check_response_data(expected_erratas)
    assert_response :success
    response_data = ActiveSupport::JSON.decode(response.body)
    expected_erratas.each do |errata|
      assert response_data.has_key?(errata.id.to_s)
      %w[cve update_date advisory actual_ship_date issue_date].each do |key|
        assert response_data[errata.id.to_s].has_key?(key), "Expected key #{key}"
        assert response_data[errata.id.to_s]['cve'].is_a? Array
        # (Won't bother testing the actual values)
      end
    end
  end
end
