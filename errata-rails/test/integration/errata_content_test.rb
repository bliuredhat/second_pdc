require 'test_helper'
require 'test_helper/errata_view'

class ErrataContentTest < ActionDispatch::IntegrationTest
  include PdcAdvisoryUtils
  include ErrataDetailsView
  APPLICABLE_MAPPINGS = [
    "Package Origin Destination",
    "sblim-cim-client2 - CDN",
    "rhel-6-server-rpms__6Server__x86_64 (RHEL-6) rhel-6-rhev-s-rpms__6Server-RHEV-S__x86_64 (RHEL-6-RHEV-S) Show active",
    "sblim-cim-client2 - RHN",
    "rhel-x86_64-server-optional-6 (RHEL-6) rhel-x86_64-server-6-rhevh (RHEL-6-RHEV) Show active",
  ]
  APPLICABLE_AND_MULTI_PRODUCT_ENABLED_TEXT = "Relevant multi-product mappings have been found. Based on the advisory's builds, the following multi-product mappings may apply. (Check the content lists below to see the resulting channel and repo destinations)."
  APPLICABLE_AND_MULTI_PRODUCT_DISABLED_TEXT = "Relevant multi-product mappings have been found. However, this advisory doesn't support multiple products. To enable multi-product support, please visit the advisory's Edit page."
  NO_APPLICABLE_TEXT = "No applicable multi-product mappings have been found, hence no additional content destinations have been added."

  MULTI_PRODUCT_MAPPINGS_ENABLED_ICON =  'icon-ok'
  MULTI_PRODUCT_MAPPINGS_ENABLED_TEXT = "This advisory supports multi-product destinations."

  MULTI_PRODUCT_MAPPINGS_DISABLED_ICON = 'icon-remove'
  MULTI_PRODUCT_MAPPINGS_DISABLED_TEXT = "This advisory doesn't support multi-product destinations."

  test "advisory with multi-product mappings disabled has applicable destination dists" do
    auth_as devel_user
    errata = Errata.find(13147)
    errata.update_attributes(:supports_multiple_product_destinations => false)
    errata_content_test(
      :errata => errata,
      :status_icon => MULTI_PRODUCT_MAPPINGS_DISABLED_ICON,
      :status_text => MULTI_PRODUCT_MAPPINGS_DISABLED_TEXT,
      :applicable_text => APPLICABLE_AND_MULTI_PRODUCT_DISABLED_TEXT,
      :applicable_mappings => APPLICABLE_MAPPINGS,
      :content_header => ["Build", "Direct", "Via multi-product mappings"],
      :content => 'advisory_13147_content_with_multi_product_mappings_disabled.json'
    )
  end

  test "advisory with multi-product mappings enabled has applicable destination dists" do
    auth_as devel_user
    errata = Errata.find(13147)
    errata.update_attributes(:supports_multiple_product_destinations => true)
    errata_content_test(
      :errata => errata,
      :status_icon => MULTI_PRODUCT_MAPPINGS_ENABLED_ICON,
      :status_text => MULTI_PRODUCT_MAPPINGS_ENABLED_TEXT,
      :applicable_text => APPLICABLE_AND_MULTI_PRODUCT_ENABLED_TEXT,
      :applicable_mappings => APPLICABLE_MAPPINGS,
      :content_header => ["Build", "Direct", "Via multi-product mappings"],
      :content => 'advisory_13147_content_with_multi_product_mappings_enabled.json'
    )
  end

  test "advisory without multi-product mappings and had disabled it" do
    auth_as devel_user
    errata = Errata.find(11142)
    errata.update_attributes(:supports_multiple_product_destinations => false)
    errata_content_test(
      :errata => errata,
      :status_icon => MULTI_PRODUCT_MAPPINGS_DISABLED_ICON,
      :status_text => MULTI_PRODUCT_MAPPINGS_DISABLED_TEXT,
      :applicable_text => NO_APPLICABLE_TEXT,
      :content_header => ["Build", "Direct"],
      :content => 'advisory_11142_content_without_multi_product_mappings.json'
    )
  end

  test "advisory without multi-product mappings but had enabled it" do
    auth_as devel_user
    errata = Errata.find(11142)
    errata.update_attributes(:supports_multiple_product_destinations => true)
    errata_content_test(
      :errata => errata,
      :status_icon => MULTI_PRODUCT_MAPPINGS_ENABLED_ICON,
      :status_text => MULTI_PRODUCT_MAPPINGS_ENABLED_TEXT,
      :applicable_text => NO_APPLICABLE_TEXT,
      :content_header => ["Build", "Direct"],
      :content => 'advisory_11142_content_without_multi_product_mappings.json'
    )
  end

  test "docker advisory only has CDN content" do
    auth_as devel_user
    errata = Errata.find(21100)
    errata_content_test(
      :errata => errata,
      :status_icon => MULTI_PRODUCT_MAPPINGS_DISABLED_ICON,
      :status_text => MULTI_PRODUCT_MAPPINGS_DISABLED_TEXT,
      :applicable_text => NO_APPLICABLE_TEXT,
      :content_header => ["Build", "Direct"],
      :content => 'advisory_21100_content_docker.json'
    )
  end

  test "PDC advisory content tab works correctly" do
    auth_as devel_user
    @advisory = Errata.find_by_advisory('RHBA-2015:2399-17')
    VCR.use_cassette 'content table shows in pdc advisory' do
      visit advisory_tab 'Content', advisory: @advisory
    end

    title = "RHN channel and CDN repo content"
    status_text = MULTI_PRODUCT_MAPPINGS_DISABLED_TEXT
    status_icon = MULTI_PRODUCT_MAPPINGS_DISABLED_ICON
    within(".eso-tab-content") do
      assert_equal title, all("h1")[1].text
      # show 'x' icon if multi-product mappings support was disabled
      # show tick icon if multi-product mappings support was enabled
      assert_equal status_icon, find(".step-status i")[:class]
      assert_match /#{Regexp.escape(status_text)}/, text
    end

    applicable_text = NO_APPLICABLE_TEXT
    within(".applicable_mappings") do
        assert_match /#{Regexp.escape(applicable_text)}/, text
    end

    rows = []
    # Get all rows and columns data of the table
    all(".content_list tr").each do |row|
      columns = row.all("td")
      rows << [row, columns]
    end

    assert_dist_content(
        :rows => rows,
        :content_header => ["Build", "Direct"],
        :content => 'advisory_21131_content_dist.json'
      )
  end

  test "can not fetch token from pdc server raise error" do
    auth_as devel_user
    @advisory = Errata.find_by_advisory('RHBA-2015:2399-17')
    # Raise a PDC::TokenFetchFailed exception
    PdcVariant.any_instance.stubs(:channels).raises(PDC::TokenFetchFailed)

    VCR.use_cassette 'content table shows in pdc advisory' do
      visit advisory_tab 'Content', advisory: @advisory
      assert_match /Can\'t fetch token from PDC server/, text
    end
  end

  def errata_content_test(args)
    errata = args[:errata]
    status_icon = args[:status_icon]
    status_text = args[:status_text]
    applicable_text = args[:applicable_text]
    applicable_mappings = args[:applicable_mappings]
    content_header = args[:content_header]
    content = args[:content]

    title = "Multi-product details"

    visit "/advisory/#{errata.id}"
    click_on 'Content'

    within(".eso-tab-content") do
      assert_equal title, all("h1")[0].text
      # show 'x' icon if multi-product mappings support was disabled
      # show tick icon if multi-product mappings support was enabled
      assert_equal status_icon, find(".step-status i")[:class]
      assert_match /#{Regexp.escape(status_text)}/, text

      # Check if the applicable multi-product mappings are listed correctly
      within(".applicable_mappings") do
        assert_match /#{Regexp.escape(applicable_text)}/, text
        if applicable_mappings.present?
          all("table tr").each_with_index do |tr, row|
            assert_equal applicable_mappings[row], tr.text
          end
        end
      end

      assert_equal "RHN channel and CDN repo content", all("h1")[1].text

      rows = []
      # Get all rows and columns data of the table
      all(".content_list tr").each do |row|
        columns = row.all("td")
        rows << [row, columns]
      end
      # Check if the channels and cdn repos are listed in the table correctly
      assert_dist_content(
        :rows => rows,
        :content_header => content_header,
        :content => content
      )
    end
  end

  # This method converts the data in the table to json with the following
  # format:
  # {
  #   "nvr" => {
  #     :direct => {
  #       :dist => "channel_or_cdn_repo",
  #       :files => [rpms],
  #       :listing => [product_listing_links]
  #     },
  #     :multi_product_maps => {
  #       :info => "Message",
  #       :dist => "channel_or_cdn_repo",
  #       :files => [rpms],
  #     },
  #   }
  # }
  def assert_dist_content(args)
    rows = args[:rows]
    expected_header = args[:content_header]
    expected_content = args[:content]

    all_contents = {}
    rows.each_with_index do |(row, columns), row_num|
      # Row 0 is table header
      if row_num == 0
        assert_equal expected_header.join(" "), row.text
        next
      end

      nvr = columns[0].find(".nvr").text
      row_content = Hash.new{ |h,k| h[k] = {:direct => [], :multi_product_maps => []} }
      [:direct, :multi_product_maps].each_with_index do |type, idx|
        col_num = idx + 1
        next if columns[col_num].nil?
        info = tolerate_not_found{ columns[col_num].find(".content_info").text }
        columns[col_num].all(".dist-container").each do |dist_container|
          column_content = {
            :dist  => dist_container.find(".dist_name").text,
            :files => dist_container.find(".files").all("a").map(&:text).sort,
            # Text of the product listing links comes from the prior column, but is intended
            # to match with the set of files found in this column.
            :listing => columns[idx].all('.listing-info').collect{|e| e.all('a').map(&:text)}.flatten.sort
          }
          column_content.merge!(:info => info) if info.present?
          row_content[nvr][type] << column_content
        end
        all_contents.merge!(row_content)
      end
    end
    assert_testdata_equal expected_content, formatted_response(all_contents.to_json)
  end

  # Catch the ElementNotFound error and return nil
  def tolerate_not_found
    begin
      yield
    rescue Capybara::ElementNotFound
      nil
    end
  end

  def formatted_response(data, opts={})
    [
      canonicalize_json(data, opts),
      '' # make baseline file end with newlinex
    ].join("\n")
  end
end
