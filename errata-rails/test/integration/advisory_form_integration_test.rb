require 'test_helper'

class AdvisoryFormIntegrationTest < ActionDispatch::IntegrationTest

  setup do
    auth_as admin_user
    @advisory = RHBA.qe.first

    # add more products to the QuarterlyUpdate release in order to test
    # choosing different product/releases
    @product = Product.find(77)
    # The select box options get refeshed when product option has
    # changed. Since ajax is not working in our test. It is
    # confusing to use QuarterlyUpdate.last because this could
    # easily break the test every time we update the fixtures.
    @product.releases << QuarterlyUpdate.find_by_name("RHEL-7.0.0")
    @product.save!
  end

  test "edit existing adivsory" do
    new_user = User.last
    assert_not_equal new_user, @advisory.package_owner
    assert_not_equal new_user, @advisory.manager

    visit "/errata/edit/#{@advisory.id}"

    fill_in "advisory_package_owner_email", :with => "owner_invalid"
    fill_in "advisory_manager_email",       :with => "manager_invalid"
    click_on "Preview >"

    assert_input_error('advisory_package_owner_email', 'owner_invalid is not a valid errata user')
    assert_input_error('advisory_manager_email', 'manager_invalid is not a valid errata user')

    fill_in "advisory_package_owner_email", :with => ''
    fill_in "advisory_manager_email",       :with => ''
    click_on "Preview >"

    assert_input_error('advisory_package_owner_email', 'cannot be blank')
    assert_input_error('advisory_manager_email', 'cannot be blank')

    fill_in "advisory_package_owner_email", :with => new_user.login_name
    fill_in "advisory_manager_email",       :with => new_user.login_name
    click_on "Preview >"
    click_on "Save Errata"

    @advisory.reload
    assert_equal new_user, @advisory.package_owner
    assert_equal new_user, @advisory.manager
  end

  test "new quarterly update advisory - keeps selections" do
    visit errata_new_qu_path
    assert_selections_remain_same @product
  end

  test "pdc new quarterly update pdc advisory - keeps selections" do
    # NOTE: see detailed explanation in setup method
    # product must not be the first one in the list that is already selected
    # Add a new release to it so that the release appears in the 'Releases'
    # selection when visiting the path
    pdc_product = Product.find_by_name('PDC Test Product')
    pdc_product.releases << QuarterlyUpdate.find_by_name!('ReleaseTestPdcRelease1')
    pdc_product.save!

    visit errata_new_qu_pdc_path
    assert_selections_remain_same pdc_product
  end

  def assert_selections_remain_same(product)
    refute has_select? 'product_id', :selected => product.name

    select product.name, :from => 'product_id'
    select product.releases.last.name, :from => 'release_id'

    # NOTE: Create should result in error since packages are not selected
    old_path = current_path
    click_button 'Create'

    assert_equal old_path, current_path
    assert has_select? 'product_id', :selected => product.name
    assert has_select? 'release_id', :selected => product.releases.first.name
  end

  test "create new manual advisory with preselected defaults" do
    visit '/errata/new'

    fields = [
      'Red Hat Bug Fix Advisory',
      'advisory[enable_embargo_date]',
      'advisory[enable_release_date]',
    ]
    fields.each {|fieldname| assert(has_checked_field?(fieldname), "#{fieldname} not checked") }
  end

  test "should not list PDC release in creating new manual advisory" do
    # a product with is_pdc being true chould be used
    # to create PDC and legacy advisory.
    # manual creation only support legacy advisory
    @product.update_attributes!(:supports_pdc => true)
    @product.update_attributes!(:pdc_product_id=>3)
    legacy_release = @product.releases.first
    release = Release.find_by_name("PDCTestRelease")
    release.update_attributes!(:product => @product)

    visit '/errata/new_qu'

    select @product.name, :from => 'product_id'
    select legacy_release.name, :from => 'release_id'
    assert_raises(Capybara::ElementNotFound) do
      select release.name, :from => 'release_id'
    end
  end

  test "comment form available on new advisory" do
    no_comments = Errata.new_files.last
    with_comments = Errata.qe.last

    #
    # Verify if the comment form is provided. Otherwise the javascript
    # can't unhide the form and the user can't add comments.
    # Bug: 985262
    #
    [no_comments, with_comments].each do |advisory|
      visit "/advisory/#{advisory.id}"
      assert has_css?('#state_comment_form form', visible: false)
      assert_equal 1, all('#state_comment_form', visible: false).count
    end
  end

  test "request docs approval" do
    advisory = RHBA.new_files.where_docs_approved.first
    old_description = advisory.content.description
    assert advisory.docs_approved?
    refute advisory.docs_approval_requested?

    visit "/errata/edit/#{advisory.id}"
    fill_in  "advisory_description", :with => "Change me"
    click_on "Preview >"
    check    "Request docs approval"
    click_on "Save Errata"

    advisory.reload
    assert_not_equal old_description, advisory.content.description
    assert_equal     "Change me"    , advisory.content.description
    assert           advisory.docs_approval_requested?
  end

  test "cannot create advisory with empty release" do
    # can't use admin_user as that will select ASYNC release
    auth_as devel_user

    # pick a product with no release defined
    product = Product.find_by_short_name('RHCS')
    bug = Bug.unfiled.with_states('MODIFIED').last
    assert product.active_releases.empty?

    visit '/errata/new'

    select product.name, :from => 'product_id'
    fill_in 'advisory_idsfixed', :with => bug.id.to_s

    #
    # The Preview button is hidden with Javascript, but it doesn't
    # prevent the user to submit the form with simply hitting the
    # 'Enter' button twice. See Bug #1053567.
    #
    click_on 'Preview >'
    click_on 'Preview >'

    assert has_text? "Release can't be blank"
  end

  test "pdc release should not be listed in legacy manual creation" do
    # can't use admin_user as that will select ASYNC release
    auth_as devel_user
    product = Product.find_by_name('PDC Test Product')
    release = Release.find_by_name("PDCTestRelease")
    release.update_attributes!(:product => product)

    visit '/errata/new'

    select product.name, :from => 'product_id'
    assert_raises(Capybara::ElementNotFound) do
      select release.name, :from => 'release_id'
    end
  end

  test "workflow shows CDN push option" do
    advisory = Errata.new_files.first
    refute advisory.supports_cdn?
    visit "/advisory/#{advisory.id}"
    refute has_text? "Push to CDN"

    assert rhba_async.supports_cdn?
    visit "/advisory/#{rhba_async.id}"
    assert has_text? "Push to CDN"
  end

  test "rhsa synopsis unchanged by default" do
    visit_test_rhsa

    # Modify any field and go to preview...
    check 'Text only?'
    click_on 'Preview >'

    # NOTE: this test is affected by this bug https://github.com/jnicklas/capybara/issues/1068
    # It causes all text areas to appear as changed (leading newline added) whenever the form
    # is submitted.  Workaround: don't test those fields!

    # Shouldn't be any synopsis change displayed
    refute has_text?('synopsis changed:'), page.html
  end

  test "rhsa synopsis change when changing impact" do
    rhsa = visit_test_rhsa

    syn = rhsa.synopsis_sans_impact
    select 'Low', :from => 'advisory[security_impact]'
    click_on 'Preview >'

    pre = find('pre', :text => 'synopsis changed:')
    assert pre.has_text?(<<-"eos"), page.html
      -Moderate: #{syn}
      +Low: #{syn}
      eos

    click_on "Save Errata"
    rhsa.reload
    assert_equal "Low: #{syn}", rhsa.synopsis
    assert_equal syn, rhsa.synopsis_sans_impact
  end

  # Bug 920907
  test "rhsa synopsis impact removed when converting to rhba" do
    e = visit_test_rhsa

    syn = e.synopsis_sans_impact

    # NOTE [capybara 2.0.3] can't choose 'Red Hat Bug Fix Advisory'
    # since it returns two radio buttons with that name (pdc and non-pdc)
    choose 'advisory_errata_type_rhba'

    click_on 'Preview >'

    pre = find('pre', :text => 'synopsis changed:')
    assert pre.has_text?(<<-"eos"), page.html
      -Moderate: #{syn}
      +#{syn}
      eos

    click_on "Save Errata"
    # note: reload doesn't work after type changes
    e = Errata.find(e.id)
    assert_equal 'RHBA', e.errata_type
    assert_equal syn, e.synopsis
    assert_equal syn, e.synopsis_sans_impact
  end

  # Bug 1074730
  test "multi product support can only be set by certain roles" do
    locator = 'Support Multiple Products?'
    assert_shows_field_by_role(locator, admin_user)
    assert_shows_field_by_role(locator, releng_user)
    assert_shows_field_by_role(locator, secalert_user)
    assert_shows_field_by_role(locator, devel_user, false)
    assert_shows_field_by_role(locator, pm_user, false)
    assert_shows_field_by_role(locator, docs_user, false)
  end

  # Return the table cell which contains an input specified by +input_id+.  This
  # can be used to find elements expected to be displayed alongside the input in
  # the same cell, e.g. help or error messages.
  def form_cell_for_input(input_id)
    find(:xpath, "//td[.//input[@id=\"#{input_id}\"]]")
  end

  # Assert that, in the last response, the input given by +input_id+ was not
  # accepted, with a particular error +message+.
  def assert_input_error(input_id, message)
    assert form_cell_for_input(input_id).find('.field_errors').has_content?(message)
  end

  def assert_shows_field_by_role(locator, user, visible=true)
    auth_as user
    visit '/errata/new'
    if visible
      assert (has_text? locator), "#{locator} not shown for user #{user.roles.map(&:name).join(',')}"
    else
      assert (has_no_text? locator), "#{locator} not expected for user #{user.roles.map(&:name).join(',')}"
    end
  end

  # Bug 1074730
  test "creates multi product supported advisory" do
    topic = 'Test topic'
    bug = Bug.unfiled.with_states('MODIFIED').last
    # use secalert to skip bug eligibility checks, which are not
    # important for this test.
    auth_as secalert_user

    visit '/errata/new'

    # NOTE [capybara 2.0.3] can't choose 'Red Hat Security Advisory'
    # since it returns two radio buttons with that name (pdc and non-pdc)

    choose 'advisory_errata_type_rhsa'

    fill_in 'advisory[topic]', :with => topic
    fill_in 'advisory[description]', :with => 'libbeer not in the fridge'
    fill_in 'advisory[synopsis]', :with => 'Here and here'
    fill_in 'advisory[idsfixed]', :with => bug.id.to_s
    click_on 'Preview >'
    click_on "Save Errata"

    refute page.has_text? 'MULTI-ON'

    advisory = RHSA.last
    assert_equal topic, advisory.topic

    # supports_multiple_product_destinations is nil by default
    # Bug: 1373336
    assert advisory.supports_multiple_product_destinations.nil?
  end

  test "advisory can be created without any bugs or issues" do
    topic = 'Test advisory with no bugs'
    auth_as devel_user
    visit '/errata/new'

    # NOTE [capybara 2.0.3] can't choose 'Red Hat Bug Fix Advisory'
    # since it returns two radio buttons with that name (pdc and non-pdc)
    choose 'advisory_errata_type_rhba'

    fill_in 'advisory[topic]', :with => topic
    fill_in 'advisory[description]', :with => 'This advisory is fully debugged'
    fill_in 'advisory[synopsis]', :with => 'Here and there'
    click_on 'Preview >'
    click_on "Save Errata"

    advisory = RHBA.last
    assert_equal topic, advisory.topic

    assert advisory.bugs.empty?
    assert advisory.jira_issues.empty?
  end

  test "pdc advisory can be created without any bugs or issues" do
    topic = 'Test advisory with no bugs'
    auth_as devel_user
    visit '/errata/new'

    # NOTE [capybara 2.0.3] can't choose 'Red Hat Bug Fix Advisory'
    # since it returns two radio buttons with that name (pdc and non-pdc)
    choose 'advisory_errata_type_rhba'

    fill_in 'advisory[topic]', :with => topic
    fill_in 'advisory[description]', :with => 'This advisory is fully debugged'
    fill_in 'advisory[synopsis]', :with => 'Here and there'
    click_on 'Preview >'
    click_on "Save Errata"

    advisory = RHBA.last
    assert_equal topic, advisory.topic

    assert advisory.bugs.empty?
    assert advisory.jira_issues.empty?
  end

  def visit_test_rhsa
    auth_as secalert_user
    rhsa = Errata.find(11149)

    assert_equal 'Moderate: JBoss Enterprise Web Server 1.0.2 update', rhsa.synopsis

    visit "/errata/edit/#{rhsa.id}"

    # On the form, synopsis should display without the impact, since that's not editable
    assert has_field?('advisory[synopsis]', :with => 'JBoss Enterprise Web Server 1.0.2 update'), page.html

    rhsa
  end
end
