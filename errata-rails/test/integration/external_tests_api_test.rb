require 'test_helper'

class ExternalTestsApiTest < ActionDispatch::IntegrationTest

  API = 'api/v1/external_tests'

  # Only using fixture records up to this one, to keep the test stable if new
  # fixtures are introduced
  MAX_RUN = 85

  setup do
    auth_as admin_user
  end

  test "index baseline" do
    ExternalTestRun.with_scope(:find => {:conditions => ["external_test_runs.id <= ?", MAX_RUN]}) do
      with_baselines(API, %r{\/index(?:_(.+))?\.json$}) do |_, params|
        get [API, params].join('?')
        formatted_json_response
      end
    end
  end

  test "show baseline" do
    with_baselines(API, %r{\/show_(.+)\.json$}) do |_, params|
      get [API, params].join('/')
      formatted_json_response
    end
  end
end
