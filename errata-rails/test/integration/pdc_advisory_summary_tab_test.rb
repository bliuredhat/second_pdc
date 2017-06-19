require 'test_helper'
require 'test_helper/errata_view'

class PdcAdvisoryBuildTabTest < ActionDispatch::IntegrationTest
  include ErrataDetailsView
  include PdcAdvisoryUtils

  setup do
    auth_as devel_user
  end

  test 'builds are listed on summary' do
    advisory = pdc_advisory('RHBA-2015:2399-17')

    VCR.use_cassette 'pdc_advisory_21131_summary_tab' do
      visit advisory_tab 'Summary', advisory: advisory
    end

    # ensure I can see the builds
    within_builds_section do
      builds_header = find('h2 > a').text
      assert_equal 'Builds (1)', builds_header
    end

    within_builds_content do
      first_col_header = find('table > thead th:nth-child(1)')
      assert_equal 'PDC Release', first_col_header.text

      data_row = find_all('table > tbody > tr > td').map(&:text)

      expected = ['ceph-2.1-updates@rhel-7', 'ceph-10.2.3-17.el7cp', '']
      assert_array_equal expected, data_row

      # link to PDC Release exists
      pdc_release_link = find('table > tbody td:nth-child(1) > a')
      assert_equal 'https://pdc.engineering.redhat.com/release/ceph-2.1-updates@rhel-7/', pdc_release_link['href']
    end
  end

  def within_builds_content
    within_builds_section do
      within('div.section_content > div') do
        yield
      end
    end
  end

  def within_builds_section
    within('#eso-content div.eso-tab-content > div:nth-child(5)') do
      yield
    end
  end
end
