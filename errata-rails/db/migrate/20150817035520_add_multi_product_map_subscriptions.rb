class AddMultiProductMapSubscriptions < ActiveRecord::Migration
  def up
    DIST_TABLES.each do |dist, table_name|
      create_table(table_name) do |t|
        t.references "multi_product_#{dist}_map".to_sym, :null => false
        # These both refer to the "user" table.
        # subscriber is the user interested in the map.
        # who is the user who created/modified the map (i.e. standard audit column)
        t.integer :subscriber_id, :null => false
        t.integer :who_id, :null => false
        t.timestamps
      end
      # Note: because the table name is quite long, the default names of these
      # indexes are too long.
      add_foreign_key table_name, ["subscriber_id"],
                      "users", ["id"], :name => "mp_#{dist}_subscriber_fk"
      add_foreign_key table_name, ["who_id"],
                      "users", ["id"], :name => "mp_#{dist}_who_fk"
      add_foreign_key table_name, ["multi_product_#{dist}_map_id"],
                      "multi_product_#{dist}_maps", ["id"], :name => "mp_#{dist}_map_fk"
    end
  end

  def down
    DIST_TABLES.reverse.each do |dist, table_name|
      drop_table table_name
    end
  end

  DISTS = %w[cdn_repo channel]

  DIST_TABLES = DISTS.map{|dist| [dist, "multi_product_#{dist}_map_subscriptions"]}
end
