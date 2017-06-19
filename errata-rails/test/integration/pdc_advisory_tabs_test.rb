require 'test_helper'
require 'test_helper/errata_view'

class PdcErrataTabsTest < ActionDispatch::IntegrationTest
  include ErrataDetailsView
  include PdcAdvisoryUtils

  setup do
    auth_as devel_user
    @advisory = Errata.find_by_advisory('RHBA-2015:2399-17')
  end

  test 'pdc advisory tabs' do
    VCR.use_cassette 'pdc_advisory_tabs' do
      visit advisory_tab 'Summary', advisory: @advisory
    end
    tabs = within_tabbar { find_all('a') }

    # tabs and expected order of the tabs
    tabs_expected = [
      'Summary',
      'Details',
      'Builds',
      'RPMDiff',
      'CCAT',
      'Content',
      'Docs',
      'Test Results'
    ]

    assert_array_equal tabs_expected, tabs.map(&:text)
  end

end

