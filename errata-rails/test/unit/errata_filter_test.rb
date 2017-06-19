require 'test_helper'

class ErrataFilterTest < ActiveSupport::TestCase

  test "system filters give expected result counts" do
    results = ActiveSupport::OrderedHash.new
    %w[qe new_files rel_prep push_ready shipped_live].each do |status|
      results[status] = Errata.send(status).count
    end

    SystemErrataFilter.in_display_order.each do |f|
      f.filter_params['pagination_option'] = 'all'
      results[f.name] = f.results.count
    end

    result_str = results.map{|k,v| "#{k}: #{v}"}.join("\n")

    assert_testdata_equal 'errata_filter/system.txt', result_str
  end


  #
  # About to refactor/DRY the code in ErrataFilter that creates
  # these (unsightly) things. Make sure I don't break them.
  #
  test "filter defaults" do

    assert_equal(
      {"show_type_RHEA"=>"1",
      "show_type_RHSA"=>"1",
      "show_type_RHBA"=>"1",
      "show_state_QE"=>"1",
      "show_state_REL_PREP"=>"1",
      "show_state_NEW_FILES"=>"1",
      "show_state_PUSH_READY"=>"1"},
      ErrataFilter::FILTER_DEFAULTS
    )

    assert_equal(
      {"show_state_DROPPED_NO_SHIP"=>"1",
      "show_type_RHEA"=>"1",
      "show_type_RHSA"=>"1",
      "show_type_RHBA"=>"1",
      "show_state_QE"=>"1",
      "show_state_REL_PREP"=>"1",
      "show_state_IN_PUSH"=>"1",
      "show_state_SHIPPED_LIVE"=>"1",
      "show_state_NEW_FILES"=>"1",
      "show_state_PUSH_READY"=>"1"},
      ErrataFilter::FILTER_DEFAULTS_ALL
    )

    assert_equal(
      {"show_type_RHEA"=>"1",
      "show_type_RHSA"=>"1",
      "show_type_RHBA"=>"1",
      "show_state_QE"=>"1",
      "show_state_REL_PREP"=>"1",
      "show_state_IN_PUSH"=>"1",
      "show_state_SHIPPED_LIVE"=>"1",
      "show_state_NEW_FILES"=>"1",
      "show_state_PUSH_READY"=>"1"},
      ErrataFilter::FILTER_DEFAULTS_NOT_DROPPED
    )

    # Bonus state sort order test
    assert_equal(
      {"QE"=>1,
      "DROPPED_NO_SHIP"=>5,
      "PUSH_READY"=>3,
      "REL_PREP"=>2,
      "SHIPPED_LIVE"=>6,
      "IN_PUSH"=>4,
      "NEW_FILES"=>0},
      State.sort_order
    )

    # Bonus sanity check for ErrataType::ALL_TYPES
    assert_equal ErrataType.all.map(&:name).sort, ErrataType::ALL_TYPES.sort

  end

  def build_errata_filter(params)
    errata_filter = { 'name' => '' }
    filter_params = { 'pagination_option' => 'all' }
    filter_params.merge!(ErrataFilter::FILTER_DEFAULTS)

    params.each do |param|
      filter_params.merge!({ param[:field] => param[:value] })
      filter_params.merge!({ "#{param[:field]}_not" => '1' }) if param[:negate]
    end

    errata_filter['filter_params'] = filter_params
    return UserErrataFilter.new(errata_filter).results
  end

  # Returns the default errata included by the filter.
  # (Needed since the filter tests below merge with the default filter).
  def default_errata
    Errata.active.
      # Advisories in IN_PUSH state are missing from active advisories since
      # State::OPEN_STATE doesn't include IN_PUSH state. A bug is complaining
      # about this. https://bugzilla.redhat.com/show_bug.cgi?id=1328660
      # Until it's resolved, let's tweak this by excluding IN_PUSH from active
      # advisories.
      where('status != "IN_PUSH"').
      order('id DESC')
  end

  test 'filter results return correct advisories' do
    test_cases = [
      { :field => 'product', :value => [40,41],
        :expected => lambda{|e,v| e.where(:product_id => v)} },
      { :field => 'release', :value => [147,164,269],
        :expected => lambda{|e,v| e.where(:group_id => v)} },
      { :field => 'qe_group', :value => [107],
        :expected => lambda{|e,v| e.where(:quality_responsibility_id => v)} },
      { :field => 'qe_owner', :value => [3000001],
        :expected => lambda{|e,v| e.where(:assigned_to_id => v) } },
      { :field => 'reporter', :value => [3000076, 3000530],
        :expected => lambda{|e,v| e.where(:reporter_id => v) } },
      { :field => 'devel_group', :value => [142,503],
        :expected => lambda{|e,v| e.joins(:package_owner).where(:users => {:user_organization_id => v})} },
      { :field => 'security_approval', :value => %w[not_requested],
        :expected => lambda{|e,_| e.where(:security_approved => nil)} },
      { :field => 'security_approval', :value => %w[not_requested requested],
        :expected => lambda{|e,_| e.where(:security_approved => [nil, false])} },
      { :field => 'security_approval', :value => %w[requested approved],
        :expected => lambda{|e,_| e.where(:security_approved => [false, true])} },
      { :field => 'security_approval', :value => %w[requested],
        :expected => lambda{|e,_| e.where(:security_approved => false)} },
      { :field => 'security_approval', :value => %w[approved],
        :expected => lambda{|e,_| e.where(:security_approved => true)} },
    ]

    test_cases.each do |test_case|
      total = 0
      2.times do |num|
        value = test_case[:value]
        name = [
          ('NOT' if test_case[:negate]),
          test_case[:field],
          test_case[:value],
        ].compact.join(' ')

        expected_results = if test_case[:negate]
          default_errata.where('id not in (?)', test_case[:expected].call(Errata, value))
        else
          test_case[:expected].call(default_errata, value)
        end

        errata_filter = build_errata_filter([test_case])

        # make sure the filter records is not empty
        assert !errata_filter.empty?, name

        # make sure the total filter records are correct
        assert_equal expected_results.count, errata_filter.count, name

        # make sure the filter records are match as expected
        assert_equal expected_results.map(&:id), errata_filter.map(&:id), name
        test_case[:negate] = true
      end
    end
  end

  test 'filter works with unembargoed scope' do
    Errata.with_unembargoed_scope do
      errata_filter = build_errata_filter([])
      refute errata_filter.empty?
    end
  end

  test 'filter group_by sort order' do
    test_cases = [
      # Sort by Product Name (Z-A) overrides default group_by sorting
      { :params => [
          { :field => 'group_by', :value => 'product' },
          { :field => 'sort_by_fields', :value => ['proddesc', 'batch'] }
        ],
        :expected => lambda { |f| f.first.product.name > f.last.product.name } },
      # Group by sorting takes precedence over sort by fields
      { :params => [
          { :field => 'group_by', :value => 'product' },
          { :field => 'sort_by_fields', :value => ['batch', 'new'] }
        ],
        :expected => lambda { |f| f.first.product.name < f.last.product.name } },
      # Sort by Release Name (Z-A) overrides default group_by sorting
      { :params => [
          { :field => 'group_by', :value => 'release' },
          { :field => 'sort_by_fields', :value => ['reldesc', 'new'] }
        ],
        :expected => lambda { |f| f.first.release.name > f.last.release.name } },
      # Group by sorting takes precedence over default sort order
      { :params => [
          { :field => 'group_by', :value => 'release' },
        ],
        :expected => lambda { |f| f.first.release.name < f.last.release.name } },
    ]

    test_cases.each do |test_case|
      filter = build_errata_filter(test_case[:params])
      assert test_case[:expected].call(filter), test_case.inspect
    end
  end

end
