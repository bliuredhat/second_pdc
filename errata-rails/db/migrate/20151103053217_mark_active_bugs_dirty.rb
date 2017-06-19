class MarkActiveBugsDirty < ActiveRecord::Migration
  def up
    # We've recently introduced the fetching of bug depends_on/blocks.  In order
    # to initially populate that, we'll mark every bug currently on an active
    # advisory as "dirty" (needs to be re-fetched).
    #
    # Use INSERT ... SELECT syntax to be speedy.
    # (I'm expecting about 6000 - 7000 bugs here and don't want to do
    # that many inserts.)
    #
    select_sql = FiledBug.
      where(:errata_id => Errata.active).
      select('distinct bug_id, "DirtyBug", NOW()').
      to_sql

    insert_sql = [
      "INSERT INTO `dirty_records` (`record_id`, `type`, `last_updated`)",
      select_sql
    ].join(' ')

    execute insert_sql
  end

  def down
  end
end
