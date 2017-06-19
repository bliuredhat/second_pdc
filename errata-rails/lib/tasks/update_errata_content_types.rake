namespace :errata do
  def update_content_types(errata_to_update)
    puts "About to update #{errata_to_update.count} errata, this may take a while..."
    update_count = 0
    errata_to_update.find_in_batches(batch_size: 100) do |group|
      group.each(&:update_content_types)
      update_count += group.count
      puts "  #{update_count} records updated..."
    end
    puts "Done!"
  end

  desc "Set content_types where not already set"
  task :set_content_types => :environment do
    update_content_types(Errata.where('content_types IS NULL'))
  end
end
