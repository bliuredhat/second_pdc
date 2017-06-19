require 'test_helper'

class ErrataSummaryTest < ActionDispatch::IntegrationTest
  test 'builds table omits file types when only RPMs' do
    e = Errata.find(11152)

    mappings = e.build_mappings
    assert_equal 1, mappings.length
    assert_nil mappings.first.brew_archive_type

    builds_table_test(
      :errata => e,
      :expected_row_count => 1,
      :verify_header => lambda{|header|
        text = header.map(&:text)
        refute text.include?('File Types')
      },
      :verify_row => lambda{|row|
        text = row.map(&:text).join(' ')
        # should have the build NVR, but no mention of file types
        assert text.include?('xorg-x11-drv-qxl-0.0.12-2.el5'), text
        refute text.include?('RPM'), text
      })
  end

  test 'multiple file types display appropriately in builds table' do
    e = Errata.find(16409)

    # should have three mappings, all for the same build but different
    # types
    mappings = e.build_mappings
    assert_equal 3, mappings.length
    assert_equal 1, mappings.map(&:brew_build).uniq.length
    assert_equal 3, mappings.map(&:brew_archive_type_id).uniq.length

    builds_table_test(
      :errata => e,
      :expected_row_count => 1,
      :verify_header => lambda{|header|
        text = header.map(&:text)
        assert text.include?('File Types'), text.join(', ')
      },
      :verify_row => lambda{|row|
        text = row.map(&:text)
        # should have at least the build NVR and the file types
        assert text.include?('spice-client-msi-3.4-4')
        assert text.include?('RPM, msi, zip')
      })
  end

  test "request rcm push of rhsa" do
    e = Errata.find(19028)
    assert e.status_is?(:PUSH_READY)

    # Request RCM push option not available (no security approval)
    auth_as secalert_user
    visit "/advisory/#{e.id}"
    refute page.has_content?('Request RCM Push')

    # Request security approval
    e.security_approved = false
    e.save

    # Approve
    e.security_approved = true
    e.save(:validate => false)

    # Now it's approved, the option should be there
    visit "/advisory/#{e.id}"
    assert page.has_content?('Request RCM Push')

    # Request RCM Push only available to product security users
    auth_as devel_user
    visit "/advisory/#{e.id}"
    refute page.has_content?('Request RCM Push')

    # Do the request
    auth_as secalert_user
    visit "/advisory/#{e.id}"
    assert page.has_content?('Request RCM Push')
    click_on 'Request RCM Push'

    assert page.has_content?('RCM push requested at')
    assert find('div#flash_notice').has_content?('Requested RCM push')
    assert e.reload.rcm_push_requested?

    # The option should still be available
    assert page.has_content?('Request RCM Push')

    # Option only available for PUSH_READY
    e.change_state!(:REL_PREP, admin_user)
    auth_as secalert_user
    visit "/advisory/#{e.id}"
    refute page.has_content?('Request RCM Push')

  end

  def builds_table_test(args)
    errata = args[:errata]

    auth_as devel_user
    visit "/advisory/#{errata.id}"

    build_count = errata.brew_builds.uniq.length

    # The builds table header should display the number of builds,
    # which may differ from the number of mappings
    assert_equal "Builds (#{build_count})", find(:xpath, builds_table_header).text

    within(:xpath, builds_table) do
      header = all('thead th')
      col_count = header.length
      args[:verify_header].call(header)

      rows = all('tbody tr')
      assert_equal args[:expected_row_count], rows.length

      rows.each do |row|
        cells = row.all('td')

        # column count in the body should equal the count in the
        # header
        assert_equal col_count, cells.length

        args[:verify_row].call(cells)
      end
    end
  end

  def builds_table_header
    '//h2[.//*[contains(text(), "Builds")]]'
  end

  def builds_table
    "#{builds_table_header}//following::table[1]"
  end

  def field_value_xpath(name)
    "//td[text()='#{name}' and @class='small_label']/following::td[1]"
  end

end
