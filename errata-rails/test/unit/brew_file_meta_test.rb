require 'test_helper'

class BrewFileMetaTest < ActiveSupport::TestCase
  VALID_ATTRS = {
    :errata_id => 16396,
    :brew_file_id => 698253,
    :title => 'some title'
  }

  test 'rejects very short title' do
    assert_raises(ActiveRecord::RecordInvalid) {
      create_with_title!('x')
    }
  end

  test 'rejects very long title' do
    assert_raises(ActiveRecord::RecordInvalid) {
      create_with_title!('x' * 1000)
    }
  end

  test 'accepts appropriate title' do
    assert_nothing_raised {
      create_with_title!('RHEL Workstation DVD')
    }
  end

  test 'rejects duplicate for file' do
    BrewFileMeta.create!(VALID_ATTRS)
    assert_raises(ActiveRecord::RecordInvalid) {
      BrewFileMeta.create!(VALID_ATTRS)
    }
  end

  def create_with_title!(title)
    BrewFileMeta.create!(VALID_ATTRS.merge(:title => title))
  end

  test 'find or init skips files removed from an advisory' do
    e = Errata.find(16409)
    get_meta_raw = lambda{ BrewFileMeta.where(:errata_id => e).order('id ASC').to_a }
    get_meta = lambda{ BrewFileMeta.find_or_init_for_advisory(e).sort_by(&:id) }

    meta_raw = get_meta_raw.call
    meta = get_meta.call

    # Initial count.
    # Every non-rpm file on the advisory has metadata,
    # and find_or_init returned every record for the advisory
    assert_equal 6, meta.length
    assert_equal 6, e.brew_files.nonrpm.length
    assert_equal meta_raw, meta

    # Now unmap the zip files and reload
    e.build_mappings.where(:brew_archive_type_id => BrewArchiveType.find_by_name!('zip')).each(&:obsolete!)
    e.reload
    new_meta_raw = get_meta_raw.call
    new_meta = get_meta.call

    # The two zip files are no longer returned by find_or_init
    assert_equal 4, new_meta.length
    assert_equal 4, e.brew_files.nonrpm.length
    # ... although the meta records do still exist, unmodified
    assert_equal new_meta_raw, meta_raw
  end

  test 'complete scope and method match' do
    complete_meta = BrewFileMeta.complete
    incomplete_meta = BrewFileMeta.incomplete

    assert_equal BrewFileMeta.where('id NOT IN (?)', complete_meta).to_a.sort_by(&:id), incomplete_meta.sort_by(&:id)

    assert complete_meta.count > 1, 'no complete BrewFileMeta in fixtures'
    complete_meta.each do |meta|
      assert meta.complete?, "complete mismatch on #{meta.id}"
    end

    assert incomplete_meta.count > 1, 'no incomplete BrewFileMeta in fixtures'
    incomplete_meta.each do |meta|
      refute meta.complete?, "incomplete mismatch on #{meta.id}"
    end
  end

  test 'files not explicitly ranked are ranked at the end' do
    e = Errata.find(16409)

    # make the meta editable
    e.change_state!('NEW_FILES', devel_user)

    files = e.brew_files.nonrpm.order('id DESC').to_a
    assert_equal 6, files.length

    meta = BrewFileMeta.set_rank_for_advisory(e, [
      # can handle ids and objects
      files[1].id,
      files[0],
      files[3]
    ])

    # it should have returned all the meta, in rank order
    assert_equal 6, meta.length
    assert_equal meta.sort_by(&:rank), meta
    assert_equal([
      files[1],
      files[0],
      files[3],
      # below this point, the files were implicitly ranked by ID (and hence
      # opposite order as in 'files' array where they were ordered descending)
      files[5],
      files[4],
      files[2],
    ], meta.map(&:brew_file))

    # same behavior applies if the ranks were already set
    meta.each(&:save!)
    meta = BrewFileMeta.set_rank_for_advisory(e, [files[5],files[0]])

    assert_equal 6, meta.length
    assert_equal meta.sort_by(&:rank), meta
    assert_equal([
      files[5],
      files[0],
      files[4],
      files[3],
      files[2],
      files[1],
    ], meta.map(&:brew_file))
  end

  test 'metadata of locked advisory is not editable' do
    e = Errata.find(16409)
    assert e.filelist_locked?

    meta = e.brew_file_meta.last

    # initially valid...
    assert_valid meta

    # ...but modifying it makes it invalid
    meta.title = 'a new title'
    refute meta.valid?

    meta.reload

    meta.rank = 123
    refute meta.valid?
  end
end
