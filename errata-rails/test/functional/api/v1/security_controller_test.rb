require 'test_helper'

class Api::V1::SecurityControllerTest < ActionController::TestCase

  setup do
    @test_variants = [
      "5Server-SJIS-5.3.z",
      "5Server-RHNTools-5.6.z",
      "6Server-STS",
      "6Server-RHHC",
      "4AS-MRG-Grid-1.0",
      "4AS-MRG-Grid-Execute-Node-1.0",
      "4ES-MRG-Grid-1.0",
      "4AS-MRG-Messaging-Base-1.0",
      "4ES-MRG-Messaging-Base-1.0",
      "5Client-Supplementary",
      "5Client-Supplementary-5.6.Z",
      "5Client-Supplementary-5.7.Z"
    ]
  end

  test "get cpes" do
    # No authentication required for api/v1/security/cpes.json

    Variant.with_scope( :find => Variant.where(:name => @test_variants) ) do
      get :cpes, :format => :json
    end

    assert_testdata_equal "api/v1/security/cpes.json", formatted_json_response
  end

end
