# Run once, only after migration 20130516190823_add_actual_ship_date
#
namespace :one_time_scripts do
  desc "Sets up initial push targets after conversion"
  task :set_actual_ship_date => :environment do
    puts "Getting actual ship date, if it can be determined"
    # Let's say the actual ship date is the time when the errata's status
    # transitioned to SHIPPED_LIVE. We can get that from the activities table.
    # (Related to Bz 736902)
    ships = Errata.shipped_live.collect {|e| [e, e.activities.status_changes.to_status('SHIPPED_LIVE').most_recent.first.try(:created_at)]}
    missing, with_actual = ships.partition {|s| s[1].nil?}

    puts "Updating #{with_actual.length} advisories that have a ship date"
    with_actual.each {|s| s[0].update_attribute(:actual_ship_date, s[1])}
    puts "Setting #{missing.length} advisories actual_ship_date to issue_date"
    Errata.update_all "actual_ship_date = issue_date", :id => missing.collect {|m| m[0].id}
    puts "Done"
  end
end
