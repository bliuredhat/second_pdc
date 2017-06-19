class AddReleaseTypeToCdnRepos < ActiveRecord::Migration
  def up
    add_column :cdn_repos, :release_type, :string, :null => false, :default => 'PrimaryCdnRepo'
    add_index :cdn_repos, :release_type
    # There are some fastrack repos already in live, so I think i will just convert it here
    CdnRepo.where("name like '%-fastrack-%'").update_all(:release_type => 'FastTrackCdnRepo')
  end

  def down
    # I think better don't delete the existing non-primary repos
    remove_index :cdn_repos, :release_type
    remove_column :cdn_repos, :release_type
  end
end
