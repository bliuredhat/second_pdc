require 'test_helper'

class RpmdiffWaiversTest < ActionDispatch::IntegrationTest

  test "waivers_for_errata" do
    auth_as qa_user

    e = Errata.find(9754)
    w = RpmdiffWaiver.waivers_for_errata(e)
    assert_equal 3, w.count

    # ack one of them to test in the UI
    w[0].ack!

    visit "/rpmdiff/waivers_for_errata/#{e.id}"

    w.each{|waiv| assert_waiver_shown(waiv)}
  end

  test "waivers_by_test" do
    auth_as qa_user

    waivers = RpmdiffWaiver.where(:test_id => 12).where('old_result != 2')
    waivers[0].ack!

    visit "/rpmdiff/waivers_by_test/12"

    assert waivers.count > 0, 'precondition failed; need at least one waiver for this test'
    waivers.each{|w| assert_waiver_shown(w)}
  end

  test "waivers_by_package" do
    auth_as qa_user

    waivers = RpmdiffWaiver.where(:package_id => 1982).where('old_result != 2')
    waivers[0].ack!

    visit "/rpmdiff/waivers_by_package/1982"

    assert waivers.count > 0, 'precondition failed; need at least one waiver for this package'
    waivers.each{|w| assert_waiver_shown(w)}
  end

  test "non-admins can not delete or edit auto-waivers" do
    auth_as qa_user

    visit url_for(:controller => :rpmdiff, :action => :list_autowaive_rules)
    refute has_button? 'Edit'
    refute has_button? 'Delete'
  end

  test "admins can manually create a new autowaive rule" do
    auth_as admin_user

    visit url_for(:controller => :rpmdiff, :action => :list_autowaive_rules)

    within("#eso-content") do
      assert page.has_link? 'New'
      click_on 'New'
    end

    assert_equal 200, page.status_code
    assert page.has_content? "New Autowaive Rule"
    assert page.has_content? 'Package Name'
    assert page.has_content? 'Subpackage Name'
    assert page.has_button? 'Apply'
    assert page.has_link? 'Cancel'
  end

  test "creates autowaive rule successfully with a detail" do
    auth_as devel_user

    result_detail = RpmdiffResultDetail.first
    visit url_for(:controller => :rpmdiff,
                  :action => :create_autowaive_rule,
                  :result_detail_id => result_detail)

    run = result_detail.rpmdiff_result.rpmdiff_run

    fill_in 'Reason', :with => 'This is an occurring problem'
    click_on 'Apply'

    assert page.has_content? 'Results for'
    assert has_link? 'Create Autowaive Rule'
    assert page.has_content? run.package_name
  end

  # Here we first get product_version, package_name, and
  # subpackage, etc from the detail, then we manully fill
  # in the create autowaive rule form. So does for the
  # following tests that need us manually create autowaive
  # rules.
  test "creates autowaive rule successfully without a detail" do
    auth_as devel_user

    detail = RpmdiffResultDetail.first
    data = get_data_for_manually_creating_autowaive_rule(detail)

    visit url_for(:controller => :rpmdiff,
                  :action => :create_autowaive_rule)

    fill_in 'Package Name', :with => data[:package_name]
    fill_in 'Subpackage Name', :with => data[:subpackage_name]
    select data[:product_version], :from => 'rpmdiff_autowaive_rule_product_version_ids'
    fill_in 'Reason', :with => 'This is an occurring problem'

    assert_difference('RpmdiffAutowaiveRule.count') do
      click_on 'Apply'
    end

    assert_equal 200, page.status_code
    assert page.has_content? 'Changes applied.'

    rule = RpmdiffAutowaiveRule.last
    assert_equal rule.package_name, data[:package_name]
    assert_equal rule.subpackage, data[:subpackage_name]
  end

  test "to creates an autowaive rule subpackage could be empty" do
    auth_as admin_user

    detail = RpmdiffResultDetail.first
    data = get_data_for_manually_creating_autowaive_rule(detail)

    visit url_for(:controller => :rpmdiff,
                  :action => :create_autowaive_rule)

    fill_in 'Package Name', :with => data[:package_name]
    select data[:product_version], :from => 'rpmdiff_autowaive_rule_product_version_ids'
    fill_in 'Expression', :with => 'Rule without subpackage could be enabled'
    fill_in 'Reason', :with => 'This is an occurring problem'
    check('Rule Enabled')
    click_on 'Apply'

    assert_equal 200, page.status_code
    assert page.has_content? "Changes applied."
  end

  test "subpackage field has the maxlength attribute set when creating an autowaive rule" do
    auth_as devel_user
    max_len_of_subpackage_name = RpmdiffAutowaiveRule.columns_hash['subpackage'].limit

    visit url_for(:controller => :rpmdiff,
                  :action => :create_autowaive_rule)

    assert_equal 200, page.status_code
    assert_equal page.find('input#rpmdiff_autowaive_rule_subpackage')['maxlength'].to_i, max_len_of_subpackage_name
  end

  test "create autowaive rule only shows warnings without permission" do
    auth_as qa_user

    visit url_for(:controller => :rpmdiff,
                  :action => :create_autowaive_rule)

    assert_equal 200, page.status_code
    assert page.has_content? 'You do not have permission to create an autowaive rule'
  end

  test "users without permission cannot see the new button that links to the creating autowaive rule page" do
    auth_as qa_user

    visit url_for(:controller => :rpmdiff, :action => :list_autowaive_rules)

    assert_equal 200, page.status_code
    within("#eso-content") do
      assert page.has_no_link? 'New'
    end
  end

  test "rpmdiff test result shows no create autowaive rule button without permission" do
    auth_as qa_user
    visit_rpmdiff_result_detail_page
    assert page.has_no_link? 'Create Autowaive Rule'
  end

  test "rpmdiff test result shows create autowaive rule button with permission" do
    auth_as releng_user
    visit_rpmdiff_result_detail_page
    assert has_link? 'Create Autowaive Rule'
  end

  test "show an autowaive rule without edit or delete autowaive rule link" do
    with_current_user(admin_user) do
      rpmdiff_autowaive_rule(
                             :created_by => admin_user,
                             :created_at => Time.now.utc.to_s,
                             :approved_by => admin_user,
                             :approved_at => Time.now.utc.to_s,
                             :active => true
                             )
    end

    auth_as devel_user

    rule = RpmdiffAutowaiveRule.last
    visit url_for(:controller => :rpmdiff, :action => :show_autowaive_rule, :id => rule.autowaive_rule_id)
    assert_equal 200, page.status_code
    assert page.has_content? "RPMDiff Autowaive Rule"
    assert page.has_content? 'Package Name'
    assert page.has_content?  rule.package_name
    assert has_link? 'Edit'
    refute has_link? 'Delete'
  end

  test "show an autowaive rule with an edit link" do
    with_current_user(admin_user) do
      rpmdiff_autowaive_rule(
                             :created_by => admin_user,
                             :created_at => Time.now.utc.to_s,
                             :approved_by => admin_user,
                             :approved_at => Time.now.utc.to_s,
                             :active => true
                             )
    end

    auth_as admin_user

    rule = RpmdiffAutowaiveRule.last
    visit url_for(:controller => :rpmdiff, :action => :show_autowaive_rule, :id => rule.autowaive_rule_id)
    assert_equal 200, page.status_code
    assert page.has_content? "RPMDiff Autowaive Rule"
    assert page.has_content? 'Package Name'
    assert page.has_content?  rule.package_name
    assert page.has_link? 'Edit'
    refute page.has_content? 'Heads up!'

    click_on 'Edit'
    assert_equal 200, page.status_code
    assert page.has_content? 'Edit Autowaiver'
  end

  def visit_rpmdiff_result_detail_page
    result = RpmdiffResultDetail.first.rpmdiff_result
    run = result.rpmdiff_run
    visit url_for(:controller => :rpmdiff, :action => :show, :id => run, :result_id => result)
  end

  def get_data_for_manually_creating_autowaive_rule(detail)
    data = {}
    run = detail.rpmdiff_result.rpmdiff_run
    data[:subpackage_name] = detail.subpackage
    if ! data[:subpackage_name]
      data[:subpackage_name] = 'all'
    end
    data[:package_name] = run.package_name
    data[:product_version] = run.errata_brew_mapping.product_version.name
    return data
  end

  def assert_waiver_shown(w)
    tr_xpath = %Q<//tr[@id="rpmdiff_waiver_#{w.id}"]>
    text_xpath = %Q<#{tr_xpath}/td[text()="#{w.description}"]>
    assert page.has_xpath?(tr_xpath), "missing row for waiver #{w.inspect}\n#{page.html}"
    assert page.has_xpath?(text_xpath), "missing text for waiver #{w.inspect}\n#{page.html}"

    if w.acked?
      column_with_text = lambda{ |text| %Q<#{tr_xpath}/td[contains(text(), "#{text}")]> }
      acked_by_xpath        = column_with_text.call(w.acked_by.realname)
      ack_description_xpath = column_with_text.call(w.ack_description || '--')
      assert page.has_xpath?(acked_by_xpath),        "missing 'acked by' for #{w.inspect}\n#{page.html}"
      assert page.has_xpath?(ack_description_xpath), "missing ack text for #{w.inspect}\n#{page.html}"
    end
  end
end
