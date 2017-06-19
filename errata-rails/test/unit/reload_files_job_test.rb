require 'test_helper'

class ReloadFilesJobTest < ActiveSupport::TestCase
  test 'skip if mapping deleted' do
    deleted_mapping = mock('ErrataBrewMapping') do
      stubs(:id => 1)
      stubs(:current? => true)
      stubs(:for_rpms? => true)
    end

    ErrataBrewMapping.expects(:find_by_id).with(deleted_mapping.id).returns(nil)
    force_sync_delayed_jobs do
      BrewJobs::ReloadFilesJob.enqueue(deleted_mapping)
    end
  end

  test 'skip if advisory not NEW_FILES' do
    qe_errata = Errata.qe.first

    qe_mapping = mock('ErrataBrewMapping') do
      stubs(:id => 2, :errata => qe_errata)
      stubs(:current? => true)
      stubs(:for_rpms? => true)
    end

    ErrataBrewMapping.expects(:find_by_id).with(qe_mapping.id).returns(qe_mapping)
    force_sync_delayed_jobs do
      BrewJobs::ReloadFilesJob.enqueue(qe_mapping)
    end
  end

  test 'run if conditions are satisfied' do
    new_files_errata = Errata.new_files.first
    brew_build = mock('BrewBuild') do
      stubs(:nvr => nil)
    end
    product_version = mock('ProductVersion') do
      stubs(:short_name => nil)
    end
    ok_mapping = mock('ErrataBrewMapping') do
      stubs(:id => 3, :errata => new_files_errata)
      expects(:reload_files => nil)
      stubs(:brew_build).returns(brew_build)
      stubs(:pv_or_pr).returns(product_version)
      stubs(:current? => true)
      stubs(:for_rpms? => true)
    end

    ErrataBrewMapping.expects(:find_by_id).with(ok_mapping.id).returns(ok_mapping)
    assert_difference('new_files_errata.comments.count', 1) do
      force_sync_delayed_jobs do
        BrewJobs::ReloadFilesJob.enqueue(ok_mapping)
      end
    end
  end

end
