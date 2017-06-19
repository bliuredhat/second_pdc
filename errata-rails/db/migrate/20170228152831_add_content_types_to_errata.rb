#
# To set content_types for existing errata, use
#   `rake errata:set_content_types`
#
class AddContentTypesToErrata < ActiveRecord::Migration
  def up
    add_column :errata_main, :content_types, :text

    # set content_types for existing errata
    Rake::Task['errata:set_content_types'].invoke
  end

  def down
    remove_column :errata_main, :content_types
  end
end
