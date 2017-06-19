class ForeignKeys < ActiveRecord::Migration
  def self.up
    add_foreign_key "errata_content", ["doc_reviewer_id"], "users", ["id"], :name => "doc_reviewer_fk"  
    add_foreign_key "rpmdiff_runs", ["package_id"], "packages", ["id"]
    add_foreign_key "tpsjobs", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "tpsjobs", ["rhn_channel_id"], "rhn_channels", ["id"]
    add_foreign_key "tpsjobs", ["product_variant_id"], "errata_versions", ["id"]
  end

  def self.down

  end
end
