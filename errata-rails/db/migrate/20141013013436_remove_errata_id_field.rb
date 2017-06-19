class RemoveErrataIdField < ActiveRecord::Migration
  def up
    ActiveRecord::Base.transaction do
      # Fix any advisory with unmatched errata_id and id
      # we will only worry about active advisories
      Errata.active.where('errata_main.id != errata_main.errata_id').each do |errata|
        # skip if the advisory has live advisory name
        # This advisory is ok to have different errata_id and id
        next unless errata.old_advisory.nil? && errata.live_advisory_name.nil?
        # fix the full advisory
        errata.set_fulladvisory
        errata.save!
      end
    end
    remove_column :errata_main, :errata_id
    change_column :errata_main, :fulladvisory, :string, :null => true
  end

  def down
    # will spend about 10 minutes to rollback
    change_column :errata_main, :fulladvisory, :string, :null => false
    add_column :errata_main, :errata_id, :integer, :null => false
    Errata.select("id, old_advisory").each do |errata|
      # we can't bring back 100% errata_id as before the migration, because some old
      # advisories might not followed the rule below.
      errata_id = if (errata.has_live_id_set?)
        errata.live_advisory_name.live_id
      else
        errata.id
      end
      errata.update_column(:errata_id, errata_id)
    end
  end
end

