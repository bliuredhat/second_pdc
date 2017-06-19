#
# This uses Capybara to do some integration tests.
# See https://github.com/jnicklas/capybara#readme
#
# Trying out a few things with capybara. Will probably
# put serious behaviour tests in their own separate files.
#
require 'test_helper'

class BasicsTest < ActionDispatch::IntegrationTest
  include ApplicationHelper # defines object_row_id method
  fixtures :all


  #
  # Check that our custom 'auth_as' method works okay
  #
  test "no kerberos auth" do
    auth_as nil
    visit '/errata'
    assert page.has_content? 'To use the Errata Tool you must authenticate with valid Kerberos credentials.'
    assert_equal 401, page.status_code
  end

  test "no user found" do
    auth_as 'no_such_user@redhat.com'
    visit '/errata'
    assert page.has_content? 'Access to the Errata Tool is limited'
    assert_equal 403, page.status_code
  end

  test "logged in user can see list" do
    auth_as admin_user
    visit '/errata'
    assert page.find('h1').has_content? 'Advisories'
    assert page.has_selector? '#eso-content'
  end

  ###
  ### This needs redoing for 2.3 UI.
  ### (Was mostly a test of how to do stuff with capybara anyhow...)
  ###
  #
  # Search for one advisory by synopsis then search for another.
  # (It seems unlikely to ever happen, but this might fail if there
  # are more than one page of results matching the search term).
  #
  #test "search by synopsis" do
  #  # Grab a couple of advisories arbitrarily from the fixtures data
  #  test_errata = [11152, 11149]
  #
  #
  #  # Go to the main list page
  #  auth_as admin_user
  #  visit '/errata/listrequest.cgi'
  #
  #  test_errata.map{ |id| Errata.find id }.each do |errata|
  #    # Search by synopsis
  #    fill_in 'errata_synopsis', :with => errata.synopsis
  #    click_on 'Redisplay'
  #    # See if we found it
  #    # (Use the tr id inserted by _bz_rows to locate the tr,
  #    # then look for the name of the errata in the link in the first column)
  #    assert page.find("tr##{object_row_id(errata)} a").has_content?(errata.advisory_name)
  #  end
  #end

  test "smoke test all main menu links" do
    # Go to the main home page
    auth_as admin_user
    visit '/errata'

    # Grab all links from the main menu
    main_nav_links = page.all('#eso-topnav .eso-inner ul li a').map { |link| link[:href] }

    main_nav_links.each do |main_nav_link|
      visit main_nav_link
      assert page.has_selector?('#eso-content'), "#{main_nav_link} page has no content_div"
      # TODO: check it doesn't contain an exception message

      assert_no_bad_html_escaping("#{main_nav_link} has unescaped HTML")
    end

  end

  test "smoke test HTML escaping" do
    auth_as admin_user

    # This list mainly comes from clicking around and finding
    # vulnerable pages, particularly those identified from bug
    # 1155423.  It looks at both RHBA and RHSA since there are some
    # different visible fields for each.
    %w[
      /advisory/16409
      /errata/details/16409
      /advisory/11145
      /errata/details/11145
      /errata/details/8854
      /errata/edit_depends_on/18905
      /errata/details/18905
      /errata/edit/11149
      /advisory/16397/builds
      /brew/edit_file_meta/16397
      /docs/show/16397
      /errata/test_results/16397
      /advisory/16409/rpmdiff_runs
      /rpmdiff/show/47686?result_id=760560
      /bugs/troubleshoot?bug_id=1029796
      /workflow_rules/1
      /rpmdiff/manage_waivers/11105
      /ftp_exclusions/lookup_package_exclusions?pkg=jboss-wfk
      /jira_issues/MAITAI-1249/advisories
      /product_versions/16/channels/129
      /product_versions/244/variants/699
      /variants/699/cdn_repos/1275
      /advisory/19463
    ].each do |url|
      visit url
      assert_no_bad_html_escaping("bad HTML escaping at #{url}")
    end
  end

  def assert_no_bad_html_escaping(message = nil)
    content = page.text

    # Getting some escaped html thanks to the html_safe stuff in rails 3
    # Let's blow up if we see any of these.
    assert_no_match(/<a href=/, content, message)
    assert_no_match(/<td/,      content, message)
    assert_no_match(/<span/,    content, message)
    assert_no_match(/<div/,     content, message)
    assert_no_match(/<br/,      content, message)
    assert_no_match(/<tt/,      content, message)

    # Find any kind of HTML entity
    assert_no_match(/&([a-zA-Z0-9]+|#[0-9]+|#x[0-9a-fA-F]+);/,
                                   content, message)

    # Find HTML elements wrongly embedded into page title.
    #
    # FIXME: our capybara doesn't have any API for getting page title.
    # We check it via native element (Nokogiri), which may not be
    # portable if we change the capybara backend later.  Could be
    # fixed by upgrading capybara.
    title = page.find('title', visible: false).native
    assert(
      title.children.length == 1 && title.children.first.text?,
      [
        message,
        "title should be text only, but seems to contain HTML:",
        title.to_s,
      ].join("\n")
    )
  end

  test 'logs request timing' do
    logs = capture_logs do
      visit '/workflow_rules/1'
    end

    logs = logs.select{|l| l[:logger] == 'requests' }
    messages = logs.map{|l| l[:msg]}
    full_log = messages.join("\n")

    assert_equal 3, messages.length, full_log

    # Messages should all start with the same tag
    assert_match /^\[[0-9a-f]+\] /, messages[0]
    tag = Regexp.quote(messages[0].split.first)

    assert_match %r{^#{tag} Started GET "/workflow_rules/1"}, messages.shift
    assert_match /^#{tag} Parameters:.*"controller"=>"workflow_rules"/, messages.shift
    # note 401 since we didn't auth
    assert_match %r{^#{tag} Completed GET "/workflow_rules/1".*\(time: \d+\.\d\d, status: 401\)$}, messages.shift
  end
end
