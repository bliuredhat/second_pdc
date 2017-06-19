class AddTextOnlyCpe < ActiveRecord::Migration
  def self.up
    #
    # If I make this a string I get an error:
    #   Mysql::Error: Row size too large. The maximum row size for the used table type,
    #   not counting BLOBs, is 65535. You have to change some columns to TEXT or BLOBs.
    # So making it a text instead.
    #
    # Some other fields have a 4000 limit so making this one 4000 also just to be
    # consistent.
    #
    add_column :errata_content, :text_only_cpe, :text, :limit => 4000
  end

  def self.down
    remove_column :errata_content, :text_only_cpe
  end
end
