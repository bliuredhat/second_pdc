class UpdateMultiToUnsetWhereApplicable < ActiveRecord::Migration
  def up
    # All the multi-enabled advisories
    multi_enabled_errata = Errata.where(:supports_multiple_product_destinations => true)
    puts "#{multi_enabled_errata.count} multi-enabled advisories found"

    # Advisories without possible multi-product mappings
    errata_without_possible_mappings = multi_enabled_errata.select do |e|
      MultiProductMap.possibly_relevant_mappings_for_advisory(e).none?
    end

    if errata_without_possible_mappings.any?
      puts "#{errata_without_possible_mappings.count} candidate advisories to unset found"

      # Unset multi-products support for the advisories that do not have
      # possible multi-product mappings
      errata_without_possible_mappings.each do |e|
        begin
          e.update_attributes!(:supports_multiple_product_destinations => nil)
          puts "#{e.advisory_name} has unset 'Support Multiple Products'"
        rescue => ex
          puts "Failed to unset 'Support Multiple Products' for #{e.advisory_name}! #{ex}"
        end
      end
    else
      puts "No candidate advisories to unset found"
    end
  end

  def down
    # Do nothing, but if need to do this then we could check the log to find out
    # which advisories have been unset and manually enable them back.
  end
end
