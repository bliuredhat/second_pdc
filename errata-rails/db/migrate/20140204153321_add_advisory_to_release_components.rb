class AddAdvisoryToReleaseComponents < ActiveRecord::Migration
  def change
    add_column :release_components, :errata_id, :integer,  :foreign_key => false
  end
end
