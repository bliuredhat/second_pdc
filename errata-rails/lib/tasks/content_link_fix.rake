#
# Sometimes we want to update old urls to new urls in advisories'
# solution (or other) text. See Bug 986894.
#
# Note: only open advisories are updated. Shipped or dropped advisories
# are left alone.
#
namespace :content_link_fix do

  desc "Update link in solution (or other field) text"
  task :update_link => :environment do
    old_link = ENV['OLD'] or raise "Specify old link using OLD='http://example.com/'"
    new_link = ENV['NEW'] or raise "Specify new link using NEW='http://example.com/'"
    field_to_update = ENV['FIELD'] || 'solution'

    errata_to_update = Content.where("#{field_to_update} like '%#{old_link}%'").order('id').map(&:errata).select(&:is_open_state?)

    puts "Old: #{old_link}"
    puts "New: #{new_link}"
    raise "No open advisories found with that link in #{field_to_update}." if errata_to_update.empty?

    ask_to_continue_or_cancel("Found #{errata_to_update.count} open advisories containing the old link in their #{field_to_update} content field.")

    puts "\nExample modification:"
    puts "--- Old:\n#{errata_to_update.last.content.send(field_to_update)}\n---\n"
    puts "--- New:\n#{errata_to_update.last.content.send(field_to_update).gsub(old_link, new_link)}\n---\n\n"

    ask_to_continue_or_cancel("Check the above looks okay then continue to modify #{errata_to_update.count} advisories.")

    errata_to_update.each do |errata|
      errata.content.update_attribute(field_to_update, errata.content.send(field_to_update).gsub(old_link, new_link))
      puts errata.id
    end

  end

end
