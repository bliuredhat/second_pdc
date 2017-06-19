require 'test_helper'

class CorsTest < ActionDispatch::IntegrationTest

  test "cors headers are set for whitelisted origins" do
    # ends in .redhat.com
    allowed_host = 'http://test.host.errata.redhat.com'

    page.driver.header 'Origin', allowed_host
    errata = Errata.find(18_917)
    visit "/errata/get_channel_packages/#{errata.id}?format=json"

    cors_header = 'Access-Control-Allow-Origin'
    assert_equal allowed_host, response_headers[cors_header]
  end

  test "cors headers are not set for origins not in whitelist" do
    origin = 'http://test.example.com'  # does not end in .redhat.com

    page.driver.header 'Origin', origin
    errata = Errata.find(18_917)
    visit "/errata/get_channel_packages/#{errata.id}?format=json"

    cors_header = 'Access-Controller-Allow-Origin'
    assert_equal nil, response_headers[cors_header]
  end

end
