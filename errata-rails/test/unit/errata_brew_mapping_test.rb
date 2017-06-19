require 'test_helper'

class ErrataBrewMappingTest < ActiveSupport::TestCase

  setup do
    @mapping = ErrataBrewMapping.find(23831)
    @errata = @mapping.errata
  end

  test "validates product version" do
    pv = ProductVersion.first
    build = BrewBuild.last
    # pick a product version which does not belong to this advisory
    refute @errata.available_product_versions.include? pv

    mapping = ErrataBrewMapping.new(:product_version => pv,
                                    :errata => @errata,
                                    :brew_build => build,
                                    :package => build.package)
    refute mapping.valid?
    assert_match %r{Invalid product version}, mapping.errors.values.join

    assert ErrataBrewMapping.new(:product_version => @errata.available_product_versions.last,
                                 :errata => @errata,
                                 :brew_build => build,
                                 :package => build.package).valid?
  end

  test "reload files list will change added_index" do
    # (Some assertions in this test assume that TPS CDN is disabled)
    Settings.stubs(:enable_tps_cdn).returns(false)

    ProductListing.stubs(:get_brew_product_listings => {})
    @mapping.brew_build.stubs(:import_files_from_rpc)
    @errata.stubs(:rpmdiff_finished? => true)
    original_added_index = @mapping.added_index

    # give a respin changed
    @errata.change_state!(State::QE, devel_user)
    @errata.change_state!(State::NEW_FILES, devel_user)
    @mapping.reload_files
    reload_added_index = @mapping.added_index

    assert_not_equal(original_added_index, reload_added_index, "reload files should change state index")

    old_comments = @errata.comments.to_a
    # respin state from NEW_FILES to QE will trigger rescheduled all TPS Jobs
    # event
    assert_difference '@errata.comments.count', 3 do
      @errata.change_state!(State::QE, devel_user)
    end
    @errata.reload
    new_comments = @errata.comments.to_a - old_comments
    texts = new_comments.map(&:text)
    build_texts = texts.select{|t| t.include?('9 TPS jobs rescheduled due to changed builds')}
    assert_equal 1, build_texts.length
  end

  test "reload_files loads new brew files" do
    fake_rpc_rpms = [
      {'id' => 100000010, 'arch' => 'x86_64', 'nvr' => 'some-rpm-1.0.0-1.0'},
      {'id' => 100000011, 'arch' => 'ppc64',  'nvr' => 'some-rpm-1.0.0-1.0'},
    ]

    ProductListing.stubs(:get_brew_product_listings => {})
    Brew.any_instance.expects(:listBuildRPMs).returns(fake_rpc_rpms)
    Brew.any_instance.expects(:listArchives).at_least_once.returns([])

    @errata.change_state!(State::QE, devel_user)
    @errata.change_state!(State::NEW_FILES, devel_user)

    assert_difference('@mapping.brew_files.count', 2) do
      @mapping.reload_files
    end
  end

  test 'adds user to CC when adding build' do
    e = Errata.find(16397)
    refute e.cc_users.include?(devel_user)

    with_current_user(devel_user) {
      add_build_for_cc_test(e)
    }

    assert e.reload.cc_users.include?(devel_user)
  end

  test 'does not add non-mail-receiving user to CC when adding build' do
    e = Errata.find(16397)
    refute e.cc_users.include?(devel_user)

    devel_user.update_attribute(:receives_mail, false)
    with_current_user(devel_user) {
      add_build_for_cc_test(e)
    }

    refute e.reload.cc_users.include?(devel_user)
  end

  test 'does not add user to CC when adding build if preference was set' do
    e = Errata.find(16397)

    devel_user.preferences[:omit_cc_on_add_build] = true
    devel_user.save!

    with_current_user(devel_user) {
      add_build_for_cc_test(e)
    }

    refute e.reload.cc_users.include?(devel_user)
  end

  # This behavior was chosen to be compatible with
  # CarbonCopyController, which also refuses to add users to CC if
  # they don't have 'errata' role
  test 'does not add non-errata user to CC when adding build' do
    e = Errata.find(16397)

    devel_user.roles = devel_user.roles - [Role.find_by_name!('errata')]
    devel_user.save!

    with_current_user(devel_user) {
      add_build_for_cc_test(e)
    }

    refute e.reload.cc_users.include?(devel_user)
  end

  test 'does not add duplicate entry to CC list' do
    e = Errata.find(16397)

    CarbonCopy.create!(:errata => e, :who => devel_user)
    old_cc_list = e.reload.cc_list

    with_current_user(devel_user) {
      add_build_for_cc_test(e)
    }

    assert_equal old_cc_list, e.reload.cc_list
  end

  test 'CC observer does nothing when no current user' do
    e = Errata.find(16397)

    old_cc_list = e.cc_list

    with_current_user(nil) {
      add_build_for_cc_test(e)
    }

    assert_equal old_cc_list, e.reload.cc_list
  end

  test 'cannot add bogus flags' do
    @mapping.flags_will_change!
    @mapping.flags << 'made-up-flag' << 'other-flag'
    refute @mapping.valid?
    refute @mapping.save

    errors = @mapping.errors.full_messages.join("\n")
    assert_match(/\bother-flag is not a valid flag\b/, errors)
    assert_match(/\bmade-up-flag is not a valid flag\b/, errors)
  end

  test 'cannot add bogus flags on new mapping' do
    e = Errata.find(10808)
    mapping = ErrataBrewMapping.new(
      :errata => e,
      :product_version => e.available_product_versions.first,
      :flags => %w[bogus-flag].to_set,
      :brew_build => BrewBuild.find(368626))
    refute mapping.valid?

    assert_match(/\bbogus-flag\b/, mapping.errors.full_messages.join("\n"))
  end

  test 'can add valid flags' do
    @mapping.flags_will_change!
    @mapping.flags << 'buildroot-push'
    assert_valid @mapping
    @mapping.save!
  end

  test 'cannot add buildroot-push flag for invalid status' do
    e = Errata.find(13147)

    %w[DROPPED_NO_SHIP IN_PUSH SHIPPED_LIVE].each do |status|
      e.expects(:status).at_least_once.returns(status)

      mapping = e.reload.errata_brew_mappings.first
      mapping.stubs(:errata => e)
      mapping.flags_will_change!
      mapping.flags << 'buildroot-push'
      refute mapping.valid?, "mapping unexpectedly valid for status #{status}"
      refute mapping.save, "mapping unexpectedly saved for status #{status}"

      assert_match(/\bbuildroot-push may not be modified when advisory status is #{status}\b/, mapping.errors.full_messages.join)
    end
  end

  test 'cannot add buildroot-push flag for non-RPM mappings' do
    mapping = ErrataBrewMapping.for_nonrpms.find(55986)

    mapping.flags_will_change!
    mapping.flags << 'buildroot-push'
    refute mapping.valid?
    refute mapping.save

    assert_match(/\bbuildroot-push is only applicable for RPMs\b/, mapping.errors.full_messages.join)
  end

  test 'cannot add buildroot-push flag if not permitted by product version' do
    mapping = ErrataBrewMapping.find(5185)

    refute mapping.product_version.allow_buildroot_push?

    mapping.flags_will_change!
    mapping.flags << 'buildroot-push'
    refute mapping.valid?
    refute mapping.save

    assert_match(/\bbuildroot-push is not allowed for RHEL-4-MRG-Grid-1.0\b/, mapping.errors.full_messages.join)
  end

  test 'only changed flags are validated' do
    # set up the record with a bogus flag
    @mapping.flags_will_change!
    @mapping.flags << 'bogus-flag'
    assert @mapping.save(:validate => false)

    # the record should be considered valid
    assert_valid @mapping.reload

    # now try to add a valid flag, it should be accepted
    @mapping.flags_will_change!
    @mapping.flags << 'buildroot-push'
    assert_valid @mapping
    assert @mapping.save

    # adding an invalid flag still complains
    @mapping.flags_will_change!
    @mapping.flags << 'other-flag'
    refute @mapping.valid?
    refute @mapping.save

    errors = @mapping.errors.full_messages.join("\n")
    # only the new invalid flag should be complained about
    assert_match(/\bother-flag\b/, errors)
    assert_no_match(/\bbogus-flag\b/, errors)
  end

  test 'has_docker? returns true for docker images only' do
    e = Errata.find(21100)
    assert_equal 1, e.errata_brew_mappings.count
    assert e.has_docker?

    ebm = e.errata_brew_mappings.first
    assert_equal BrewArchiveType::TAR_ID, ebm.brew_archive_type_id
    assert ebm.has_docker?

    ebm.brew_archive_type = BrewArchiveType.find_by_name('ks')
    refute ebm.has_docker?
  end

  test "invalidate files for legacy build mapping" do
    build_mapping = ErrataBrewMapping.find(23770)
    assert build_mapping.errata_files.current.any?
    assert build_mapping.current?

    build_mapping.obsolete!
    refute build_mapping.errata_files.current.any?
    refute build_mapping.current?
    assert build_mapping.removed_index.present?
  end

  def add_build_for_cc_test(errata)
    pv = errata.available_product_versions.first
    build = BrewBuild.find(368625)

    refute errata.brew_builds.include?(build)

    # the attributes are picked arbitrarily, test doesn't care about
    # which build is added.
    ErrataBrewMapping.create!(
      :brew_build => build,
      :package => build.package,
      :errata => errata,
      :product_version => pv,
      :brew_archive_type => BrewArchiveType.find(2))

    assert errata.reload.brew_builds.include?(build)
  end

end
