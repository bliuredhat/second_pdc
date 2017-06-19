require 'test_helper'

class BuildApiTest < ActionDispatch::IntegrationTest
  setup do
    auth_as devel_user

    # In the case where a build doesn't exist, don't call to brew
    Brew.any_instance.stubs(:getBuild => nil)
  end

  test 'baseline test' do
    with_baselines('api/v1/build', %r{/show_(.+)\.json$}) do |file,id|
      get "/api/v1/build/#{id}"
      formatted_json_response
    end
  end
end
