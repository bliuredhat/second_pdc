require 'test_helper'

class ProductAdminTest < ActionDispatch::IntegrationTest

  setup do
    @product = Product.find(82)
    @pdc_product_with_pdc_release = Product.find_by_name('PDC Test Product')
    @pdc_product_without_pdc_release = Product.find_by_name('Product for PDC without release')
    @pdc_product_not_connected = @pdc_product_without_pdc_release
    @product_version = @product.product_versions.last
    @variant = @product_version.variants.last
    @short_name, @name, @description  = ['RHFOO', 'Red Hat Foo', 'A robust full-stack foo solution']
    @pv_name, @pv_description = ['Blue Gene 6', 'Blue Gene for RHEL 6']
    auth_as admin_user
    VCR.insert_cassette 'all_products'
  end

  teardown do
    VCR.eject_cassette
  end

  #-----------------------------------------

  def assert_validation_message_found(expected_validation_message)
    assert page.find('#errorExplanation h2').has_content?("prohibited this")
    assert page.find('#errorExplanation h2').has_content?("from being saved")
    assert page.find('#errorExplanation ul li').has_content?(expected_validation_message)
  end

  def assert_confirmation_flash_notice_found(text)
    assert page.find('#flash_notice').has_content?(text), "#{text} vs #{page.find('#flash_notice').try(:text)}"
  end

  #
  # These assert helpers are for testing the product form.
  # Could make them more generic and use the for product versions also.
  # (But let's not do that now since I don't want to spend too much time on it).
  #

  def fill_in_product_fields
    fill_in 'product_short_name', :with => @short_name
    fill_in 'product_name', :with => @name
    fill_in 'product_description', :with => @description
  end

  def click_and_assert_product_update_ok(is_create=false)
    assert_difference('Product.count', (is_create ? 1 : 0)) { within('.submit-buttons') { click_on (is_create ? 'Create' : 'Update') } }
    assert_confirmation_flash_notice_found("#{@name} was #{is_create ? "created" : "successfully updated"}.")
    assert_match %r{/products/\d+}, current_path
    [@short_name, @name, @description].each_with_index do |val, i|
      assert page.all('table.fields tr td:nth-child(2)')[i].has_content?(val)
    end
  end

  def click_and_assert_product_update_not_ok(expected_validation_message, is_create=false)
    assert_no_difference('Product.count') { within('.submit-buttons') { click_on (is_create ? 'Create' : 'Update') } }
    assert_validation_message_found(expected_validation_message)
    assert_match (is_create ? "/products" : "/products/#{@product.id}"), current_path
  end

  def click_and_assert_product_create_ok
    click_and_assert_product_update_ok(true)
  end

  def click_and_assert_product_create_not_ok(expected_validation_message)
    click_and_assert_product_update_not_ok(expected_validation_message, true)
  end

  def fill_xss_in_product_fields
    @xss_string = "\"><script type=\"text/javascript\">alert('game over')</script>"
    fill_in 'product_short_name', :with => @short_name + @xss_string
    fill_in 'product_name', :with => @name + @xss_string
    fill_in 'product_description', :with => @description + @xss_string
    fill_in 'product_valid_bug_states', :with => @xss_string
    fill_in 'product_cdw_flag_prefix', :with => @xss_string
  end

  test "create a product" do
    visit "/products"
    click_link "New Product"
    fill_in_product_fields
    click_and_assert_product_create_ok
  end

  test "in creating a product can select supports PDC" do
    visit "/products"
    click_link "New Product"
    # supports PDC should not be disabled in creation
    assert_false page.has_selector? '#product_supports_pdc[disabled]'
  end

  test "create a product with errors" do
    visit "/products"
    click_link "New Product"
    fill_in_product_fields
    fill_in 'product_name', :with => '' # oh noes!
    click_and_assert_product_create_not_ok("Name can't be blank")
    fill_in 'product_name', :with => 'Red Hat Enterprise Linux' # uh-oh!
    click_and_assert_product_create_not_ok("Name has already been taken")
    fill_in 'product_name', :with => @name
    click_and_assert_product_create_ok
  end

  test "create a pdc product with errors" do
    visit "/products"
    click_link "New Product"
    fill_in_product_fields
    page.check 'product_supports_pdc'
    fill_in 'product_name', :with => '' # oh noes!
    click_and_assert_product_create_not_ok("Name can't be blank")
    fill_in 'product_name', :with => 'Red Hat Enterprise Linux' # uh-oh!
    click_and_assert_product_create_not_ok("Name has already been taken")
  end

  test "edit a product" do
    visit "/products/#{@product.id}"
    click_link 'Edit'
    assert_equal "/products/#{@product.id}/edit", current_path
    fill_in_product_fields
    click_and_assert_product_update_ok
  end

  test "in editing a non pdc product can select supports PDC" do
    visit "/products/#{@product.id}"
    click_link 'Edit'
    assert_false page.has_selector? '#product_supports_pdc[disabled]'
  end

  test "in editing a pdc product with enabled pdc release supports pdc field disabled" do
    visit "/products/#{@pdc_product_with_pdc_release.id}"
    click_link 'Edit'
    assert page.has_selector? '#product_supports_pdc[disabled]'
  end

  test "in editing a pdc product without enabled pdc release can edit supports pdc" do
    visit "/products/#{@pdc_product_without_pdc_release.id}"
    click_link 'Edit'
    assert_false page.has_selector? '#product_supports_pdc[disabled]'
  end

  test "in editing a pdc product with enabled pdc release can not change pdc product" do
    visit "/products/#{@pdc_product_with_pdc_release.id}"
    click_link 'Edit'
    assert page.has_selector? '#product_pdc_product_id[disabled]'
  end

  test "in editing a pdc product without enabled pdc release can change pdc product" do
    visit "/products/#{@pdc_product_without_pdc_release.id}"
    click_link 'Edit'
    assert page.has_selector? '#product_pdc_product_id'
    assert_false page.has_selector? '#product_pdc_product_id[disabled]'
  end

  test "in editing a pdc product without associated product in pdc should show it as none" do
    visit "/products/#{@pdc_product_not_connected.id}"
    click_link 'Edit'
    assert page.has_selector? '#product_pdc_product_id'
    assert_false page.has_selector? '#product_pdc_product_id[disabled]'
    assert_equal find("#product_pdc_product_id").find('option[selected]').text, '---NONE---'
  end

  test "edit a product with errors" do
    visit "/products/#{@product.id}"
    click_link 'Edit'
    assert_equal "/products/#{@product.id}/edit", current_path
    fill_in_product_fields
    fill_in 'product_short_name', :with => '' # oops!
    click_and_assert_product_update_not_ok("Short name can't be blank")
    fill_in 'product_short_name', :with => @short_name
    click_and_assert_product_update_ok
  end

  test "edit a product with xss string" do
    visit "/products/#{@product.id}"
    click_link 'Edit'
    fill_xss_in_product_fields
    within('.submit-buttons') { click_on 'Update' }

    # the fields value will escapse overall xss script string
    val = "&gt;&lt;script type=\"text/javascript\"&gt;alert('game over')&lt;/script&gt;"
    # product_short_name
    assert page.all('table.fields tr td:nth-child(2)')[0].native.inner_html.include?(val)
    # product_name
    assert page.all('table.fields tr td:nth-child(2)')[1].native.inner_html.include?(val)
    # product_description
    assert page.all('table.fields tr td:nth-child(2)')[2].native.inner_html.include?(val)
    # product_valid_bug_states
    assert page.all('table.fields tr td:nth-child(2)')[3].native.inner_html.include?(val)
    if @product.is_internal?
      #product_cdw_flag_prefix
      assert page.all('table.fields tr td:nth-child(2)')[8].native.inner_html.include?(val)
    end
  end

  #-----------------------------------------

  test "add product version" do
    visit "/products/#{@product.id}/product_versions"
    click_link "New Product Version"
    fill_in 'product_version_name', :with => @pv_name
    fill_in 'product_version_description', :with => @pv_description
    assert has_select? 'product_version_sig_key_id', :selected => Settings.default_signing_key
    assert_difference('ProductVersion.count', 1) { within ('.submit-buttons') { click_on 'Create' } }
    assert_confirmation_flash_notice_found("New Product version #{@pv_name} created.")
  end

  test "add product version with error" do
    visit "/products/#{@product.id}/product_versions"
    click_link "New Product Version"
    fill_in 'product_version_name', :with => ''
    fill_in 'product_version_description', :with => @pv_description
    assert_no_difference('ProductVersion.count') { within ('.submit-buttons') { click_on 'Create' } }
    assert_validation_message_found("Name can't be blank")
    fill_in 'product_version_name', :with => @pv_name
    assert_difference('ProductVersion.count', 1) { within ('.submit-buttons') { click_on 'Create' } }
    assert_confirmation_flash_notice_found("New Product version #{@pv_name} created.")
  end

  test "edit product version" do
    visit "/products/#{@product.id}/product_versions/#{@product_version.id}"
    click_link 'Edit'
    fill_in 'product_version_description', :with => 'Foo'
    within ('.submit-buttons') { click_on 'Update' }
    assert_equal 'Foo', @product_version.reload.description
    assert_confirmation_flash_notice_found('Update succeeded.')
  end

  test "edit product version with errors" do
    visit "/products/#{@product.id}/product_versions/#{@product_version.id}"
    click_link 'Edit'
    fill_in 'product_version_name', :with => ''
    within ('.submit-buttons') { click_on 'Update' }
    assert_validation_message_found("Name can't be blank")
    fill_in 'product_version_name', :with => 'Bar'
    within ('.submit-buttons') { click_on 'Update' }
    assert_equal 'Bar', @product_version.reload.name
    assert_confirmation_flash_notice_found('Update succeeded.')
  end

  test "product version shows correct variants and attached repositories" do
    pv = ProductVersion.find_by_name!("RHEL-6")
    variants = pv.variants.sort_by(&:name)

    visit "/product_versions/#{pv.id}/"

    [
      [Channel, :channel_links, "RHN channels"],
      [CdnRepo, :cdn_repo_links, "CDN repositories"]
    ].each do |klass, link, caption|
      label = klass.name.pluralize.underscore
      within(".#{label}_tab") do
        # make sure the tabs are shown
        tab_title = "Attached #{caption}"
        assert find(:xpath, "a[@href='\##{label}_tab']").has_text?(tab_title), "Can't find '#{tab_title}' tab"
      end
      variants.each_with_index do |v,i|
        path = "//div[@id='#{label}_tab']/form[#{i + 1}]"
        within(:xpath, path) do
          panel_path = "div[contains(@class, 'panel')]"
          # make sure variant link and action buttons are shown
          [v.name, "Attach #{klass.display_name}", "Detach selected"].each do |l|
            assert find(:xpath, "#{panel_path}/div[@class='panel-heading']").has_link?(l), "Can't find #{l} link"
          end
          if (repo_count = v.send(link).count) > 0
            # make sure the correct number of repositories are listed
            assert_selector(:xpath, "#{panel_path}/table/tbody/tr", :count => repo_count)
          else
            assert find(:xpath, "#{panel_path}/table/tbody/tr").has_text?("No #{caption} are attached")
          end
        end
      end
    end
  end

  #-----------------------------------------

  test "add variant" do
    visit "/products/#{@product.id}/product_versions/#{@product_version.id}"
    click_link 'new_variant'
    select '6Server', :from => 'RHEL Variant'
    fill_in 'variant_name', :with => '6Server Blue Gene Variant'
    assert_difference('Variant.count', 1) { click_button 'Create' }
  end

  test "edit variant" do
    cpetext = 'Test CPE'
    assert @variant.cpe.empty?

    visit "/product_versions/#{@product_version.id}/variants/#{@variant.id}"
    click_link "Edit"
    fill_in 'variant_cpe', :with => cpetext
    click_on 'Update'
    @variant.reload
    assert @variant.cpe
  end

end
