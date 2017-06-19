require 'test_helper'

class RhelReleasesTest < ActionDispatch::IntegrationTest

  test "Cross Site Scripting(XSS) attack" do
    auth_as admin_user

    xss_string = %{<script type="text/javascript">alert('game over')</script>}
    visit "/rhel_releases/new"
    fill_in 'rhel_release[name]', :with => "name" + xss_string
    fill_in 'rhel_release_description', :with => "desc" + xss_string
    within('td.vbottom') { click_on 'Create' }

    escaped_xss_string = %{&lt;script type=\"text/javascript\"&gt;alert('game over')&lt;/script&gt;}

    assert page.all("table tbody tr td")[0].native.inner_html.eql? "name" + escaped_xss_string
    assert page.all("table tbody tr td")[1].native.inner_html.eql? "desc" + escaped_xss_string
  end
end
