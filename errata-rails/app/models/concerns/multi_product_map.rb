module MultiProductMap
  extend ActiveSupport::Concern
  include Audited
  include CanonicalNames

  included do
    belongs_to :origin_product_version, :class_name => 'ProductVersion'
    belongs_to :destination_product_version, :class_name => 'ProductVersion'
    belongs_to :package
    belongs_to :user

    belongs_to :origin_product_version_enabled,
               :class_name => 'ProductVersion',
               :foreign_key => "origin_product_version_id",
               :conditions => { enabled: true }
    belongs_to :destination_product_version_enabled,
               :class_name => 'ProductVersion',
               :foreign_key => "destination_product_version_id",
               :conditions => { enabled: true }

    scope :with_enabled_product_version,
      joins(:origin_product_version_enabled, :destination_product_version_enabled)

    # e.g. multi_product_cdn_repo_map_subscriptions
    subscription_relation = "#{self.name.underscore}_subscriptions".to_sym

    has_many subscription_relation
    alias_method :subscriptions, subscription_relation

    has_many :subscribers,
             :class_name => 'User',
             :through => subscription_relation

    alias :who :user
    alias :who= :user=

    validates_presence_of :origin_product_version,
                          :destination_product_version,
                          :package

    validate :origin_destination_active, :sig_keys_match, :unique_mapping
  end

  def origin_sym
    "origin_#{mapping_type}".to_sym
  end

  def destination_sym
    "destination_#{mapping_type}".to_sym
  end

  def origin
    self.send(origin_sym)
  end

  def destination
    self.send(destination_sym)
  end

  def self.mappings_for_product_version_package(product_version, package, opts={})
    active_channels = product_version.active_channels
    active_repos = product_version.active_repos

    [
      [MultiProductChannelMap, active_channels],
      [MultiProductCdnRepoMap, active_repos]
    ].map do |klass, origins|
      klass.mappings_for_package(origins, package).includes(opts[:includes])
    end.flatten.uniq
  end

  # Finds all the product versions which have multi-product mappings
  # from the given origin product version and package.
  def self.mapped_product_versions(product_version, package)
    self.mappings_for_product_version_package(product_version, package, :includes=>:destination_product_version).map(&:destination_product_version).uniq
  end

  # Finds the possibly relevant multi-product mappings for an advisory based on its builds.
  # ("Possibly" meaning the mappings would have some effect if `supports_multiple_product_destinations`
  # was set for the advisory.)
  # TODO: Support PDC
  def self.possibly_relevant_mappings_for_advisory(errata)
    return [] if errata.is_pdc?
    errata.errata_brew_mappings.map do |errata_brew_mapping|
      self.mappings_for_product_version_package(errata_brew_mapping.product_version, errata_brew_mapping.package)
    end.flatten
  end

  def mapping_type
    self.class.mapping_type
  end

  protected

  def sig_keys_match
    return if any_required_fields_nil?

    unless origin_product_version.sig_key == destination_product_version.sig_key
      err = ["Signing keys must match between product versions. ",
             "#{origin_product_version.name } has signing key #{origin_product_version.sig_key.name}; whereas ",
             "#{destination_product_version.name} has key #{destination_product_version.sig_key.name}."].join
      errors.add(:origin_product_version, err)
    end
  end

  def unique_mapping
    return if any_required_fields_nil?
    # Could use validates_uniqueness_of, but this gives a more meaningful error message
    filter = "#{origin_sym}_id = #{origin.id} and
             #{destination_sym}_id = #{destination.id} and
             package_id = #{package.id}"
    filter += " and id != #{id}" if self.id
    if self.class.where(filter).any?
      errors.add(origin_sym,
                 "A mapping already exists for #{origin.name} => #{destination.name} for package #{package.name}")
    end
  end

  def any_required_fields_nil?
    [origin, destination, origin_product_version, destination_product_version, package].any? {|x| x.nil?}
  end

  def origin_destination_active
    # handled by presence_of validation if nil
    return if any_required_fields_nil?

    type = mapping_type.to_s
    unless origin_product_version.send("active_#{type.pluralize}").include? origin
      errors.add(origin_sym, "#{origin.name} is not an active #{type.titleize} of #{origin_product_version.name}")
    end

    unless destination_product_version.send("active_#{type.pluralize}").include? destination
      errors.add(destination_sym, "#{destination.name} is not an active #{type.titleize} of #{destination_product_version.name}")
    end
  end


end
