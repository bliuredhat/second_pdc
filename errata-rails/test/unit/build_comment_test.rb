require 'test_helper'

class BuildCommentTest < ActiveSupport::TestCase
  setup do
    @errata = Errata.find(16396)
    @pdc_errata = Errata.find(21131)
  end

  test 'testdata preconditions' do
    assert_equal 'NEW_FILES', @errata.status

    # must have several mappings for the same pv & build so that we can test
    # partially removing a build
    assert_equal 3, @errata.build_mappings.length
    assert_equal 1, @errata.build_mappings.map(&:product_version_id).uniq.length
    assert_equal 1, @errata.brew_builds.length
  end

  test 'removing a build adds a comment to the advisory' do
    assert_difference('@errata.comments.count', 1) do
      ActiveRecord::Base.transaction do
        @errata.build_mappings.each(&:obsolete!)
      end
    end
    @errata.reload

    assert_equal 0, @errata.build_mappings.length
    comment = @errata.comments.last

    assert comment.is_automated?
    assert_equal 'Removed build rhel-server-docker-7.0-22 (for RHEL-7.0-Supplementary) from advisory.', comment.text
  end

  test 'removing a build adds a comment to the pdc advisory' do
   VCR.use_cassettes_for(:pdc_ceph21) do
    assert_difference('@pdc_errata.comments.count', 1) do
      ActiveRecord::Base.transaction do
        @pdc_errata.pdc_errata_release_builds.each(&:obsolete!)
      end
    end
    @pdc_errata.reload

    assert_equal 0, @pdc_errata.pdc_errata_release_builds.length
    comment = @pdc_errata.comments.last

    assert comment.is_automated?
    assert_equal 'Removed build ceph-10.2.3-17.el7cp (for ceph-2.1-updates@rhel-7) from advisory.', comment.text
   end
  end

  test 'removing a subset of files adds a comment to the advisory' do
    assert_difference('@errata.comments.count', 1) do
      ActiveRecord::Base.transaction do
        @errata.build_mappings.order('id ASC').limit(2).each(&:obsolete!)
      end
    end
    @errata.reload

    assert_equal 1, @errata.build_mappings.length
    comment = @errata.comments.last

    assert comment.is_automated?
    assert_equal 'Removed RPM, ks files of build rhel-server-docker-7.0-22 (for RHEL-7.0-Supplementary) from advisory.', comment.text
  end

  test 'rollback is ignored' do
    mappings = @errata.build_mappings.to_a

    assert_difference('@errata.comments.count', 0) do
      ActiveRecord::Base.transaction do
        mappings[0..1].each(&:obsolete!)
        raise ActiveRecord::Rollback
      end
    end

    @errata.reload
    assert_equal 3, @errata.build_mappings.length

    mapping_to_remove = @errata.build_mappings.select {|m| m.file_type_name == 'tar'}.first
    assert_difference('@errata.comments.count', 1) do
      ActiveRecord::Base.transaction do
        mapping_to_remove.obsolete!
      end
    end

    @errata.reload
    assert_equal 2, @errata.build_mappings.length
    comment = @errata.comments.last

    assert comment.is_automated?
    # the comment should only refer to the last mapping. i.e. the observer should have
    # forgotten about any mappings which were obsoleted and then rolled back
    assert_equal 'Removed tar files of build rhel-server-docker-7.0-22 (for RHEL-7.0-Supplementary) from advisory.', comment.text
  end

  test 'moving to QE after respin adds a comment with dropped and added builds' do
    ProductListing.stubs(:get_brew_product_listings => {})

    # don't care about these checks
    @errata.stubs(:rpmdiff_finished? => true)
    BrewFileMetaGuard.any_instance.stubs(:transition_ok? => true)
    # Bug 1053533: An advisory will be blocked in NEW_FILES state if a build
    # that contains rpms has missing product listing. I will simply mock
    # this check here to make the test easy.
    BuildGuard.any_instance.stubs(:transition_ok? => true)

    @errata.change_state!(State::QE, devel_user)
    @errata.change_state!(State::NEW_FILES, devel_user)
    @errata.reload

    @errata.build_mappings.each(&:obsolete!)

    # spice build has mixed content; include an RPM and a non-RPM mapping
    bb = BrewBuild.find(367585)
    nonrpm_type = bb.brew_files.map(&:brew_archive_type_id).compact.first
    pv = @errata.available_product_versions.first

    [nil, nonrpm_type].each do |type_id|
      ErrataBrewMapping.create!(
        :errata => @errata,
        :brew_build => bb,
        :product_version => pv,
        :package => bb.package,
        :brew_archive_type_id => type_id
      )
    end
    @errata.reload

    old_comments = @errata.comments.to_a

    @errata.change_state!(State::QE, devel_user)
    @errata.reload

    new_comments = @errata.comments.to_a - old_comments

    texts = new_comments.map(&:text)
    assert texts.any?

    build_texts = texts.select{|t| t.include?('builds removed')}
    assert_equal 1, build_texts.length

    msg = build_texts.first
    assert msg.include?("1 builds removed:\nrhel-server-docker-7.0-22")
    assert msg.include?("1 builds added:\nspice-client-msi-3.4-4")
  end
end
