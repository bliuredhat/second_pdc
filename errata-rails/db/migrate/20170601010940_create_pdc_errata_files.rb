class CreatePdcErrataFiles < ActiveRecord::Migration
  def change
    create_table "pdc_errata_files", :force => true do |t|
      #
      # Note:
      #
      # I've copied this directly from the db/schema entry for errata_files table.
      # I suspect some of these fields are not used any more, but rather than
      # review them all to confirm, I'll just copy them anyway. Same with
      # the indexs and foreign keys.
      #
      # The only thing different is there is a pdc_variant_id field instead of a
      # version_id field.
      #
      #
      t.integer "errata_id", :null => false
      t.integer "pdc_variant_id", :null => false
      t.integer "arch_id", :null => false
      t.string "devel_file", :limit => 4000, :null => false
      t.string "ftp_file", :limit => 4000, :null => false
      t.string "md5sum", :limit => 4000, :null => false
      t.datetime "change_when", :null => false
      t.integer "current", :default => 1, :null => false
      t.integer "who", :null => false
      t.string "signed", :default => "none", :null => false
      t.string "rhn_channels", :limit => 2000
      t.string "rhn_beta_channels", :limit => 2000
      t.string "collection", :limit => 256
      t.integer "released", :default => 0, :null => false
      t.date "rhn_pkgupload"
      t.string "rhn_shadow_channels", :limit => 2000
      t.integer "prior", :default => 0, :null => false
      t.string "epoch"
      t.integer "package_id", :null => false
      t.integer "brew_rpm_id", :default => -1, :null => false
      t.integer "brew_build_id"
      t.index ["arch_id", "pdc_variant_id", "errata_id", "id"], :name => "pdc_errata_files_idx"
      t.index ["brew_build_id"]
      t.index ["change_when", "errata_id"]
      t.index ["current", "errata_id"]
      t.index ["errata_id"]
      t.index ["package_id", "current", "errata_id"]
      t.index ["pdc_variant_id"]
      t.index ["who"]
      t.foreign_key ["arch_id"], "errata_arches", ["id"], :on_update => :restrict, :on_delete => :restrict
      t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict
      t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict
      t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict
      t.foreign_key ["pdc_variant_id"], "pdc_resources", ["id"], :on_update => :restrict, :on_delete => :restrict
      t.foreign_key ["who"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict
    end
  end

  def down
    drop_table "pdc_errata_files"
  end
end
