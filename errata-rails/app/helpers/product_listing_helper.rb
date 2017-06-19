module ProductListingHelper

  def render_product_listing_table(listing)
    render_table listing
  end

  def render_pdc_product_listing_table(listing, brew_build)
    listing_item = Struct.new(:variant_label, :brew_file, :destination_arch)
    result = []

    listing.each_pair do |variant, arches|
      arches.each_pair do |arch, rpm_arches|
        rpms = rpm_arches.to_h.keys().map(&:to_s).map(&:strip)
        brew_build.brew_files.each do |brew_file|
          m = brew_file.name.match(/(?<name>^.*)-(?<version>[^-]+)-(?<release>[^-]+)$/)
          name = m['name'].strip
          if rpms.include?(name) && rpm_arches[name].include?(brew_file.arch.brew_name)
            result << listing_item.new(variant, brew_file, Arch.find_or_create_by_name(arch))
          end
        end
      end
    end
   render_table result
  end

  def render_table(listing)
    row_func = lambda{|l| [
      l.variant_label,
      brew_file_link(l.brew_file, :brief => true),
      l.destination_arch.name
    ]}

    sort_func = lambda{|l| [
      l.variant_label,
      l.destination_arch.name,
      l.brew_file.file_subpath,
      l.brew_file.filename
    ]}

    render(:partial => "shared/bz_table", :locals => {
      :headers => %w[Variant File Arch],
      :row_items => listing.sort_by(&sort_func),
      :func => row_func
    })
  end

end
