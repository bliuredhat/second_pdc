namespace :one_time_scripts do
  desc "Removes old entries from product_listing_caches"
  task :remove_obsolete_plc_entries => :environment do
    data = Errata.connection.select_rows("select id, product_version_id, brew_build_id, max(created_at) from product_listing_caches group by product_version_id, brew_build_id")
    ids = data.map(&:first).map(&:to_i)
    puts "There are #{ids.length} unique entries"
    count = ProductListingCache.where("id not in (?)", ids).delete_all
    puts "Removed #{count} duplicates"
  end
end
