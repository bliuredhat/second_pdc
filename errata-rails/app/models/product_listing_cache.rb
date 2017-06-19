require 'yaml'
class ProductListingCache < ActiveRecord::Base

  @@Listing ||= Struct.new('ProductListingCache_Listing', :variant_label, :brew_file, :destination_arch)

  belongs_to :product_version
  belongs_to :brew_build
  validates_presence_of :brew_build, :product_version, :cache
  validates_uniqueness_of :product_version_id, :scope => [:brew_build_id]
  validate :valid_cache_format

  def errata_brew_mappings
    ErrataBrewMapping.current.where(:product_version_id => self.product_version_id, :brew_build_id => self.brew_build_id)
  end

  def empty?
    load_cache.empty?
  end

  def listings_empty?
    get_listing.empty?
  end

  def any?
    load_cache.any?
  end

  def has_errata?
    errata_brew_mappings.any?
  end

  def load_cache
    YAML.load(self.cache)
  end

  def get_listing
    return ProductListingCache.to_flat_listing(self.brew_build, load_cache)
  end

  def set_listing(listing)
    data = {}
    listing.group_by(&:variant_label).each do |(variant_label,variant_listings)|
      data[variant_label] = {}
      variant_listings.group_by(&:brew_file).each do |(brew_file,file_listings)|
        data[variant_label][brew_file.id] = file_listings.map(&:destination_arch).map(&:name).sort.uniq
      end
    end
    self.cache = data.to_yaml
  end

  # This method takes a structure in the format stored in the "cache"
  # column and produces a list of mappings.
  def self.to_flat_listing(brew_build, data)
    out = []
    return out if data.empty?

    brew_files = brew_build.cached_brew_files
    arches = Arch.cached_arches

    append_to_out = lambda do |variant_label,file,dest_arches|
      dest_arches.each do |arch_name|
        arch = arches.find{|a| a.name == arch_name}
        next if !arch

        out << @@Listing.new(variant_label, file, arch)
      end
    end

    # Old-style mapping needs to resolve RPMs by name and arch, and
    # traverse src->dest arch mappings
    handle_legacy_mapping = lambda do |variant_label,rpm_name,arch_mapping|
      arch_mapping.each do |src_arch,dest_arches|
        # fixup product listings / ET disagreement on the name of
        # the arch used for source RPMs
        if src_arch == 'src'
          src_arch = 'SRPMS'
        end
        arch = arches.find{|a| a.name == src_arch}

        file = brew_files.find{|file| file.name == rpm_name && file.arch_id == arch.id}
        next if !file

        append_to_out.call(variant_label, file, dest_arches)
      end
    end

    # New-style mapping looks up a file by ID, which maps directly to
    # dest arches
    brew_files_by_id = nil
    handle_mapping = lambda do |variant_label,brew_file_id,dest_arches|
      brew_files_by_id ||= brew_files.group_by(&:id)
      file = brew_files_by_id[brew_file_id].try(:first)
      next if !file

      append_to_out.call(variant_label, file, dest_arches)
    end

    data.each do |variant_label,variant_data|
      variant_data.each do |key,arch_mapping|
        if key.kind_of?(String)
          # Old style: key is an RPM basename, such as: libcgroup-0.40.rc1-6.el6_5.1
          handle_legacy_mapping.call(variant_label, key, arch_mapping)
        elsif key.kind_of?(Fixnum)
          # New style: key is the ID of a Brew file
          handle_mapping.call(variant_label, key, arch_mapping)
        end
      end
    end

    out
  end

  def self.prepare_cached_listings(product_version_ids, brew_build_ids)
    pvs = ProductVersion.where(:id => product_version_ids)
    pkgs = BrewBuild.where(:id => brew_build_ids).map(&:package).uniq
    mapped_pvs = []
    pvs.each do |product_version|
      pkgs.each do |package|
        mapped_pvs << MultiProductMap.
                       mapped_product_versions(product_version, package)
      end
    end
    # cached_listing contains listing for the mapped product versions
    product_version_ids << mapped_pvs.flatten.map(&:id)
    ProductListingCache.
      includes(:brew_build).
      where(:product_version_id => product_version_ids, :brew_build_id => brew_build_ids).
      each_with_object({}) do |l,h|
        h[l.product_version_id] ||= {}
        h[l.product_version_id][l.brew_build_id] = l
      end
  end

  def self.cached_listing(product_version, brew_build)
    # find listing cache from memory first if exists
    listings = ThreadLocal.get(:cached_listings)
    if listings && listings[product_version.id] && listings[product_version.id][brew_build.id]
      return listings[product_version.id][brew_build.id]
    end
    # otherwise look at the database
    cached = ProductListingCache.find_by_product_version_id_and_brew_build_id(product_version, brew_build)
    cached
  end

  private
  def valid_cache_format
    loaded_cache = load_cache
    return if loaded_cache.is_a? Hash
    errors.add(:cache, "not set as a Hash. It is a #{loaded_cache.class}")
  end
end
