class CreatePdcReleasedPackages < ActiveRecord::Migration
  def change
    create_table "pdc_released_packages", :force => true do |t|
      t.integer "pdc_variant_id", :null => false
      t.integer "package_id", :null => false
      t.integer "arch_id", :null => false
      t.string "full_path", :null => false
      t.integer "pdc_release_id", :null => false
      t.integer "current", :default => 1
      t.datetime "updated_at"
      t.string "rpm_name"
      t.integer "brew_rpm_id"
      t.integer "brew_build_id"
      t.datetime "created_at"
      t.integer "errata_id"
      t.index ["arch_id", "package_id", "pdc_variant_id"], :name => "pdc_released_package_variant_idx"
      t.index ["brew_build_id"], :name => "brew_build_id"
      t.index ["brew_rpm_id"], :name => "brew_rpm_id"
      t.index ["errata_id"], :name => "errata_released_package_idx"
      t.index ["package_id"], :name => "package_id"
      t.index ["pdc_release_id", "current"], :name => "released_package_pr_index"
      t.index ["pdc_variant_id"], :name => "pdc_variant_id"
      t.foreign_key ["arch_id"], "errata_arches", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_1"
      t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_2"
      t.foreign_key ["brew_rpm_id"], "brew_files", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_3"
      t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_4"
      t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_5"
      t.foreign_key ["pdc_release_id"], "pdc_resources", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_6"
      t.foreign_key ["pdc_variant_id"], "pdc_resources", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_7"
    end
  end
end
