class InitBrewFileMetaRank < ActiveRecord::Migration
  def up
    # If any advisory with a locked filelist exists with non-RPM
    # files, set an arbitrary rank so further transitions are not
    # blocked.
    #
    # In practice I doubt there are any.
    BrewFileMeta.joins(:errata).where('errata_main.status != "NEW_FILES"')\
      .update_all('rank = 10000 + brew_file_meta.id')
  end

  def down
    BrewFileMeta.where('rank = 10000 + id').update_all(:rank => nil)
  end
end
