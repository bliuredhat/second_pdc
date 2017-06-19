require 'test_helper'

class ErrataFilterUiTest < ActionDispatch::IntegrationTest

  setup do
    # These fields are checked by default
    default_checks = %w[
      show_type_RHSA
      show_type_RHBA
      show_type_RHEA
      show_state_NEW_FILES
      show_state_QE
      show_state_REL_PREP
      show_state_PUSH_READY
    ]

    # These options are selected by default
    @default_options = {
      :pagination_option => '20',
      :sort_by_fields_ => 'Newest',
    }

    # Test case for testing the custom filter

    products = Product.all.take(2)
    releases = Release.enabled.take(2)
    filter_1 = [
      {:field => 'errata_main.errata_type in (?)', :value => %w[RHEA RHBA PdcRHEA PdcRHBA] },
      {:field => 'errata_main.status in (?)', :value => %w[NEW_FILES QE] },
      {:field => 'product_id not in (?)', :value => products },
      {:field => 'group_id not in (?)', :value => releases },
    ]

    expected_1 = Errata.where(filter_1.map{ |f| f[:field] }.join(' and '), *filter_1.map{ |f| f[:value] }).order('errata_main.id desc')

    @test_case_1 = {
      :expected_results => expected_1,
      :uncheck_fields => %w[ show_type_RHSA show_state_REL_PREP show_state_PUSH_READY ],
      :check_fields => %w[ show_type_RHEA show_type_RHBA show_state_NEW_FILES show_state_QE product_not release_not ],
      :select_options => {
        :pagination_option => '250',
        :product => products.map(&:short_name),
        :release => releases.map(&:name),},
    }

    # Test case for testing the default active advisories filter

    filter_2 = [
      {:field => 'errata_main.errata_type in (?)', :value => ErrataType::ALL_TYPES },
      {:field => 'errata_main.status in (?)', :value => %w[NEW_FILES QE REL_PREP PUSH_READY] },
    ]

    expected_2 = Errata.where(filter_2.map{ |f| f[:field] }.join(' and '), *filter_2.map{ |f| f[:value] }).order('errata_main.id desc').paginate(:page => 1, :per_page => 20)

    @test_case_2 = {
      :expected_page => 1,
      :expected_per_page => 20,
      :expected_results => expected_2,
      :check_fields => default_checks,
    }

    # Test case for testing backward compatibility with the removed 'exlude_rhel_7' checkbox

    rhel_7 = Release.where('name LIKE "RHEL-7.%"')

    filter_3= [
      {:field => 'errata_main.errata_type in (?)', :value => ErrataType::ALL_TYPES },
      {:field => 'errata_main.status in (?)', :value => %w[NEW_FILES QE REL_PREP PUSH_READY] },
      {:field => 'group_id not in (?)', :value => rhel_7 },
    ]

    expected_3= Errata.where(filter_3.map{ |f| f[:field] }.join(' and '), *filter_3.map{ |f| f[:value] }).order('errata_main.id desc')

    @test_case_3 = {
      :expected_results => expected_3,
      :check_fields => %w[ release_not ].concat(default_checks),
      :select_options => {
        :pagination_option => '250',
        :release => rhel_7.map(&:name)},
    }

    # Test case for filtering by batch

    batch_name = 'batch_00002'
    @batch = Batch.find_by_name(batch_name)

    @test_case_4 = {
      :expected_results => Errata.where(:batch_id => @batch.id),
      :check_fields => default_checks,
      :select_options => {
        :batch => batch_name
      }
    }

    @test_case_5 = {
      :expected_results => Errata.where(:batch_id => @batch.id),
      :check_fields => default_checks,
      :expected_headings => ["batch_00002 Batch"],
      :select_options => {
        :group_by => 'Batch'
      }
    }

  end

  def check_fields(test_case)
    test_case[:check_fields].each do |name|
      check "errata_filter_filter_params_#{name}", visible: false
    end
  end

  def uncheck_fields(test_case)
    test_case[:uncheck_fields].each do |name|
      uncheck "errata_filter_filter_params_#{name}", visible: false
    end
  end

  def select_options(test_case)
    test_case[:select_options].each_pair do |field,options|
      Array.wrap(options).each do |option|
        select option, from: "errata_filter_filter_params_#{field}", visible: false
      end
    end
  end

  def assert_has_checked_fields(test_case)
    test_case[:check_fields].each do |name|
      assert has_checked_field?("errata_filter_filter_params_#{name}", visible: false)
    end
  end

  def assert_has_selected_options(test_case)
    (test_case[:select_options] || @default_options).each_pair do |field,options|
      assert has_select?("errata_filter_filter_params_#{field}",
                         with_options: Array.wrap(options), visible: false)
    end
  end

  def assert_advisories_found(test_case)
    total = test_case[:expected_results].count
    assert has_content? "#{total} advisories found"
  end

  def assert_pagination_equal(test_case)
    page = test_case[:expected_page]
    per_page = test_case[:expected_per_page]
    total = test_case[:expected_results].count
    total_page = (total.to_f / per_page).ceil
    assert has_content? "Showing page #{page} of #{total_page}" if total_page != 1
  end

  def assert_has_advisories(test_case)
    test_case[:expected_results].each do |errata|
      assert has_content? errata.advisory_name
    end
  end

  def assert_filter_name_equal(filter_name)
    assert find(:xpath, "//div[@class='filter_select_div']").has_content?(filter_name)
  end

  def assert_has_group_by_headings(test_case)
    assert_equal (test_case[:expected_headings] || []), page.all('td.group_by_header').map(&:text)
  end

  def common_asserts(test_case)
    assert_has_checked_fields(test_case)
    assert_has_selected_options(test_case)
    assert_advisories_found(test_case)
    assert_has_advisories(test_case)
    assert_has_group_by_headings(test_case)
  end

  test "errata filter with default advisories" do
    auth_as devel_user
    test_case = @test_case_2

    visit '/errata/index'
    assert find(:xpath, "//div[@class='filter_select_div']").has_content?('Active Advisories (Default)')
    common_asserts(test_case)
    assert_pagination_equal(test_case)
  end

  def unsaved_filter_test(test_case)
    auth_as devel_user

    visit '/errata/index'

    # HACK: js-workaround
    # TODO: run this using a capybara backend that supports running javascript
    #
    # NOTE: `click_on 'filter_btn_new'` will result in page.body being changed to
    # <html><head>
    #   <META HTTP-EQUIV="Refresh"  CONTENT="0; URL=/errata">
    # </head></html>
    # as javascript that shows the filter dialog does not execute and
    # e.preventDefault() won't be executed, thus commenting out:
    #
    # click_on 'filter_btn_new'

    check_fields(test_case)
    uncheck_fields(test_case)
    select_options(test_case)
    click_on 'apply_submit_btn', visible: false

    assert_filter_name_equal('(Unsaved Filter)')
    common_asserts(test_case)
  end

  test "perform errata filter as an unsaved filter" do
    unsaved_filter_test(@test_case_1)
  end

  test "can search on security approval" do
    unsaved_filter_test HashList.new.merge!(
      :select_options => {
        :security_approval => ['Requested'],
      },
      :expected_results => Errata.active.where(:security_approved => false).
        tap{|res| assert res.any?, "fixture problem, no active errata awaiting security approval"})

    assert page.has_content?('security approval requested')
  end

  test "perform errata filter and save it as a new user defined filter" do
    auth_as devel_user
    test_case = @test_case_1
    filter_name = 'my crazy filter'

    visit '/errata/index'
    # see above: HACK: js-workaround
    # click_on 'filter_btn_new'
    check_fields(test_case)
    uncheck_fields(test_case)
    select_options(test_case)
    click_on 'show_name_field_btn', visible: false
    fill_in 'filter_name', with: filter_name, visible: false

    # Force the request POST here, because the page use javascript to set
    # the request to POST which doesn't work for Capybara
    ActionDispatch::Request.any_instance.expects("post?").once.returns(true)

    click_on 'save_submit_btn', visible: false

    assert find('div#flash_notice').has_content?("Filter '#{filter_name}' created" )
    assert_filter_name_equal(filter_name)
    common_asserts(test_case)
  end

  test 'errata filter with exclude rhel-7 checkbox (backward compatible)' do
    auth_as devel_user
    test_case = @test_case_3

    # Hack the DB here to create a user defined filter
    filter = UserErrataFilter.create!(
               :user_id => devel_user.id,
               :name => 'Exclude RHEL 7',
               :filter_params => {
                 'exclude_rhel7' => "1",
                 'show_state_PUSH_READY' => "1",
                 'show_state_REL_PREP' => "1",
                 'show_state_QE' => "1",
                 'show_state_NEW_FILES' => "1",
                 'show_type_RHBA' => "1",
                 'show_type_RHEA' => "1",
                 'show_type_RHSA' => "1",
                 'pagination_option' => 'all'}
             )
    assert filter.valid?

    visit "/filter/#{filter.id}"

    assert_filter_name_equal(filter.name)
    common_asserts(test_case)
  end

  test "search IN_PUSH advisories" do
    auth_as devel_user

    # move all PUSH_READY errata to IN_PUSH
    rows_count = Errata.where(:status => ['PUSH_READY', 'IN_PUSH']).update_all(:status => 'IN_PUSH')

    assert rows_count > 0, 'Fixture data has changed. It no longer has PUSH_READY and IN_PUSH errata'

    queries = [
      { :field => 'errata_main.errata_type in (?)', :value => ErrataType::ALL_TYPES },
      { :field => 'errata_main.status in (?)', :value => %w[IN_PUSH] },
    ]

    expected_result = Errata.
      where(queries.map{ |f| f[:field] }.join(' and '), *queries.map{ |f| f[:value] }).
      order('errata_main.id desc')

    test_case = {
      :expected_results => expected_result,
      :uncheck_fields => %w[
        show_state_NEW_FILES
        show_state_QE
        show_state_REL_PREP
        show_state_PUSH_READY
      ],
      :check_fields => %w[ show_state_IN_PUSH ],
    }

    visit '/errata/index'
    # Since rack_test has no support of Javascript, all ele
    # TODO: clicking on the button refreshes the page
    #click_on 'filter_btn_modify'
    check_fields(test_case)
    uncheck_fields(test_case)
    click_on 'apply_submit_btn', visible: false

    common_asserts(test_case)
  end

  test "smoke test advisory list grouping" do
    auth_as devel_user

    # Pick a few advisories from fixtures to test list grouping
    test_advisories = Errata.where(:id=>[11110, 11112, 11118, 11119])

    Errata.with_scope(:find=>Errata.where(:id=>test_advisories)) do
      {
        # Pick a few group by options to check
        'State' => ["NEW FILES", "QE", "REL PREP", "PUSH READY"],
        'Release' => ["ASYNC Release", "RHEL-5.7.0 Release", "RHEL-6.1.0 Release"],
        'Release Date (earliest)' => ["2011-May-31 Release Date", "2011-Jul-21 Release Date", "ASAP Release Date"],
        'Release Date (latest)' => ["ASAP Release Date", "2011-Jul-21 Release Date", "2011-May-31 Release Date"],

      }.each_pair do |group_by, expected_headings|

        test_case = {
          :check_fields => [],
          :uncheck_fields => [],
          :select_options => { 'group_by' => group_by },
          :expected_results => test_advisories,
          :expected_headings => expected_headings,
        }

        visit '/errata/index'
        check_fields(test_case)
        uncheck_fields(test_case)
        select_options(test_case)
        click_on 'apply_submit_btn', visible: false
        common_asserts(test_case)
      end
    end

  end

  test "complains if filter would return too many results" do
    auth_as devel_user

    # Test DB doesn't have much errata, so we have to put the limit quite small
    Settings.max_filter_items = 50

    # Scoped so that adding more fixtures doesn't break this test
    Errata.with_scope(:find => {:conditions => 'errata_main.id <= 19829'}) do
      visit '/filter/433'

      # It should show an error message
      assert has_content?('There are too many results to display on a single page'), page.html

      # It should also show the usual filter UI (not a generic error page)
      assert has_content?("94 advisories found"), page.html

      # It should not show any advisory
      refute has_content?(Errata.first.advisory_name)
      refute has_content?(Errata.last.advisory_name)
    end
  end

  test "Show all option only appears if already set on filter" do
    auth_as devel_user

    dropdown_show_all = '//a[contains(@class, "dropdown-toggle") and contains(text(), "Show all")]'
    select_show_all = '//*[@id="errata_filter_filter_params_pagination_option"]//option[@value="all"]'

    # This filter uses "Show all", so that pagination option should appear in the UI
    visit "/filter/433"
    assert_selector(:xpath, dropdown_show_all)
    assert_selector(:xpath, select_show_all, visible: false)

    # This filter does not use "Show all", so that option should not appear
    visit "/filter/394"
    assert_no_selector(:xpath, dropdown_show_all)
    assert_no_selector(:xpath, select_show_all, visible: false)
  end

  test 'filter advisories by batch' do
    auth_as devel_user
    test_case = @test_case_4

    visit '/errata/index'
    # see above: HACK: js-workaround
    # click_on 'filter_btn_new'
    check_fields(test_case)
    select_options(test_case)
    click_on 'apply_submit_btn', visible: false
    common_asserts(test_case)
  end

  test 'group by batch' do
    auth_as devel_user

    test_case = @test_case_5

    Errata.with_scope(:find => Errata.where(:batch_id => @batch.id)) do
      visit '/errata/index'
      # see above: HACK: js-workaround
      #  click_on 'filter_btn_new'
      check_fields(test_case)
      select_options(test_case)
      click_on 'apply_submit_btn', visible: false
      common_asserts(test_case)
    end
  end
end
