# == Schema Information
#
# Table name: releases
#
#  id                 :integer       not null, primary key
#  name               :string(2000)  not null
#  description        :string(4000)
#  enabled            :integer       default(1), not null
#  isactive           :integer       default(1), not null
#  blocker_bugs       :string(2000)
#  ship_date          :datetime
#  allow_shadow       :integer       default(0), not null
#  allow_beta         :integer       default(0), not null
#  is_fasttrack       :integer       default(0), not null
#  blocker_flags      :string(200)
#  product_version_id :integer
#  is_async           :integer       default(0), not null
#  default_brew_tag   :string
#  type               :string        default("QuarterlyUpdate"), not null
#  allow_blocker      :integer       default(0), not null
#  allow_exception    :integer       default(0), not null
#

class Release < ActiveRecord::Base
  extend UrlFinder
  include ModelChild

  validates_presence_of :name, :description
  validate :pdc_type_validate_for_product
  validate :pdc_product_exists, :if => :is_pdc?

  scope :current, :conditions => { :isactive => true}
  scope :enabled, :conditions => { :enabled => true}
  scope :disabled, :conditions => { :enabled => false}
  scope :legacy, where(:is_pdc => false)
  scope :pdc, where(:is_pdc => true)
  scope :old, :conditions => { :isactive => false}
  scope :with_flags, :conditions => "blocker_flags is not null and blocker_flags != ''"
  scope :no_approved_components, :conditions => 'id not in (select release_id from release_components)'
  scope :batching_enabled, :conditions => { :enable_batching => true }
  alias_attribute :is_active, :isactive

  #
  # Find releases with a certain flag. Used to guess what release a bug should
  # belong to based on the bug's release flag.
  #
  # For release flags this should return just a single release. But if you
  # pass in 'fast' for some reason you would get many releases.
  #
  # Note that base_blocker_flags doesn't include the standard ack flags.
  # See blocker_flags and base_blocker_flags below.
  #
  # (Note also that flag_name should not include the '-', '+' or '?' suffix here)
  #
  def self.with_base_flag(flag_name)
    # Do an sql grep first so we aren't looking at every release each time,
    # but because it's a dumb grep we need the select also to avoid false hits.
    Release.where("blocker_flags like ?", "%#{flag_name}%").
      select{ |bug| bug.base_blocker_flags.include?(flag_name) }
  end

  scope :for_products, lambda { |products| { :conditions => [
    'releases.product_id in (?)', products ]}}

  scope :for_products_or_no_product, lambda { |products| { :conditions => [
    'releases.product_id IS NULL OR releases.product_id IN (?)', products ]}}

  scope :for_products_plus_async, lambda { |products| { :conditions => [
    'releases.name = ? OR releases.product_id IN (?)', 'ASYNC', products ]}}

  has_many :errata,
  :class_name => "Errata",
  :foreign_key => "group_id",
  :conditions => "is_valid = 1 and status != 'DROPPED_NO_SHIP'"

  has_and_belongs_to_many :product_versions
  has_and_belongs_to_many :pdc_releases
  belongs_to :product

  has_many :batches,
    :conditions => 'is_active = 1'

  has_many :brew_tags_releases
  has_many :brew_tags, :through => :brew_tags_releases
  has_many :release_components
  has_many :approved_components,
  :through => :release_components,
  :source => :package,
  :order => 'packages.name',
  :include => [:devel_owner, :qe_owner]

  belongs_to :program_manager, :class_name => 'User'
  belongs_to :state_machine_rule_set

  validate :check_pdc_updates_allowed, :if => :is_pdc?

  before_save do
    self.url_name = self.name.downcase.gsub('.', '_').gsub('-','_')
    self.default_brew_tag.strip! if self.default_brew_tag?
    write_attribute(:blocker_flags, base_blocker_flags.join(','))
  end

  after_save do
    Bugzilla::UpdateReleasesJob.enqueue_once
    return unless default_brew_tag?
    tag = BrewTag.find_or_create_by_name(default_brew_tag)
    return if brew_tags.include?(tag)
    brew_tags << tag
  end

  #
  def release_versions
    is_pdc? ? pdc_releases : product_versions
  end

  #
  # Can now have a per-product prefix for the CDW ack flags. See Bug 857351.
  # The first product to use this will be RHCI and the prefix will be 'hss'.
  # Returns nil if there is no prefix.
  #
  def cdw_flag_prefix
    # Some releases don't have a product hence the try is needed
    self.product.try(:cdw_flag_prefix)
  end

  #
  # The compulsory blocker flags get automatically added to
  # whatever flags the user specified for the release.
  #
  # (Probably would be more normal to override this method in the subclasses,
  # but instead going to define them here so it's easier to see them all)
  #
  def compulsory_blocker_flags
    flag_list = case self
    when QuarterlyUpdate, Zstream
      # Standard three ack flags
      %w[devel_ack qa_ack pm_ack]
    when FastTrack
      # FastTrack release can skip pm_ack
      %w[devel_ack qa_ack]
    when Async
      # Async releases can skip all ack flags
      %w[]
    else
      # (In case we make more release types)
      %w[]
    end
    # Might have to add a prefix to the flags.
    prefixed_flag_list(flag_list, cdw_flag_prefix)
  end

  #
  # base_blocker_flags are the flags the user specified.
  #
  def base_blocker_flags
    # Need to use read_attribute since we define our own blocker_flags method.
    blocker_flags_attribute = read_attribute(:blocker_flags)
    if blocker_flags_attribute.blank?
      []
    else
      # Turn the comma delimited string into an array
      # Todo: Maybe could use lib/bz_flag.rb for this (?)
      blocker_flags_attribute.split(',').map(&:strip) - compulsory_blocker_flags
    end
  end

  def release_blocker_flag
    base_blocker_flags.first
  end

  def blocker_flags_other_than_release
    blocker_flags.reject { |f| f == release_blocker_flag }
  end

  #
  # Combine the user specified flags with the compulsory flags
  #
  def blocker_flags
    (base_blocker_flags + compulsory_blocker_flags).uniq
  end

  def can_update_bugs?
    return false if blocker_flags.empty?
    self.isactive? && self.enabled?
  end

  def has_approved_components?
    approved_components.any?
  end
  # Note: This was originally for RpcBug objects, not Bug objects.
  # I wrote a has_flags? method for Bug so should be usable on either
  # now...
  #
  def has_correct_flags?(bug)
    return true unless self.blocker_flags?
    return true if bug.is_security?
    return true if bug.has_flags?(self.blocker_flags)

    # Check exceptions to ACK policy
    base_flags = read_attribute(:blocker_flags).split(',').collect {|v| v.strip}
    return true if bug.keywords =~ /Security/ && bug.has_flags?(base_flags)
    return true if allow_exception? &&  bug.has_flags?(base_flags + ['exception'])
    return true if allow_blocker? &&  bug.has_flags?(base_flags + ['blocker'])
    false

    # See also QuarterlyUpdate#has_correct_flags? which overrides this...
  end

  def is_fasttrack?
    false
  end

  def is_ystream?
    false
  end

  #
  # FastTrack releases used to override this and set a
  # default_ship_date to be the upcoming Wednesday,
  # but now it's actually nil for all releases.
  #
  # Gets used in Errata#release_ship_date (but is pretty
  # much redundant). Will leave this method in case we
  # ever reinstate some kind of default ship date for
  # releases.
  #
  def default_ship_date
    nil
  end

  #
  # If ship date is nil then return the default ship date
  #
  def use_ship_date
    ship_date || default_ship_date
  end

  #
  # Not sure if this is correct.
  # Some zstreams do have a ship date.
  # Also some QuarterlyUpdate are async and some aren't(?)
  #
  def ship_date_display
    if use_ship_date.present?
      use_ship_date.strftime('%Y-%b-%d')
    elsif is_async?
      'ASAP'
    else
      'n/a'
    end
  end

  def name_with_inactive
    "#{self.name}#{' (inactive)' if self.isactive == 0}"
  end

  # Todo: move to bug model maybe, eg
  #   def bugs
  #     Bug.for_release(self)
  #   end
  def bugs
    return Bug.where('1 = 0') if blocker_flags.empty?

    release_flag = self.release_blocker_flag
    ack_flags = self.blocker_flags_other_than_release
    base_flags = self.base_blocker_flags

    ack_flags_filter = ack_flags.collect{ |f| "flags like '%#{f}+%'" }.join(' and ')
    flag_filters = [ack_flags_filter.blank? ? "1 = 1" : ack_flags_filter]

    # note release_flag already included in outer filter, would be redundant here
    base_flags_filter = (base_flags - [release_flag]).collect{ |f| "flags like '%#{f}+%'" }.join(' and ')
    base_flags_filter += ' and ' unless base_flags_filter.empty?
    flag_filters << "#{base_flags_filter}keywords like '%Security%'"

    flag_filters << "is_blocker = 1" if allow_blocker?
    flag_filters << "is_exception = 1" if allow_exception?

    flag_filters = flag_filters.collect {|f| "(#{f})"}.join(' or ')
    filter = "flags like '%#{release_flag}+%' and (#{flag_filters})"

    logger.debug "Release bugs filter #{id} - #{name}: #{filter}"
    Bug.where filter
  end

  # Finds the set of bugs for this release. Returns an empty array
  # unless the release has blocker flags set.
  #
  # Can optionally filter on a component name
  def get_bugs(component = nil)
    return bugs if component.nil?

    pkg = Package.find_by_name(component)
    return Bug.where('1 = 0') unless pkg
    return bugs.where(:package_id => pkg)
  end

  def opml_name
    return name
  end

  def supports_component_acl?
    false
  end

  def supports_opml?
    true
  end

  def update_approved_components!
    return unless supports_component_acl?
    return unless self.base_blocker_flags.length == 1
    release_flag = self.base_blocker_flags.first
    approved = Bugzilla::Rpc.get_connection.approved_components_for release_flag

    current = self.approved_components.collect {|a| a.name}.to_set
    return if approved.empty? && current.empty?

    added = approved - current
    removed = current - approved

    return if removed.empty? && added.empty?

    unless removed.empty?
      rm_pkgs = Package.find(:all, :conditions => ['name in (?)', removed.to_a])
      ReleaseComponent.delete_all(["release_id = ? and package_id in (?)", self.id, rm_pkgs])
    end

    return if added.empty?
    new_pkgs = added.collect {|a| Package.find_or_create_by_name a }
    new_pkgs.each {|pkg| self.approved_components <<  pkg}
  end

  def update_bugs_from_rpc
    return unless can_update_bugs?
    BUGRECON.info "Checking #{self.name} for approved components"
    self.update_approved_components!
    BUGRECON.info "Done checking release"
    self.update_attribute(:bugs_last_synched_at, Time.now)
  end

  def valid_bug_states
    if is_pdc?
      return ['VERIFIED', 'MODIFIED'] if self.product.nil?
      return self.product.valid_bug_states
    end
    return ['VERIFIED', 'MODIFIED'] if self.product_versions.empty?
    states = Set.new
    self.product_versions.each {|v| states.merge(v.product.valid_bug_states)}
    states.to_a
  end

  #
  # A little helper to add the cdw_flag_prefix to a given list of flags
  # If prefix is nil or blank then just pass the flag list unchanged.
  #
  def prefixed_flag_list(flag_list, prefix)
    if prefix.present?
      flag_list.map do |flag|
        "#{prefix}_#{flag}"
      end
    else
      flag_list
    end
  end

  #
  # Newly created errata for this release will go into the batch with the
  # earliest release date that is not in the process of being released.
  #
  def next_batch
    batches.unlocked.pre_release.by_release_date.first
  end

  #
  # Returns next_batch if it exists, otherwise returns a new Batch.
  #
  def next_batch!
    return unless self.enable_batching?
    self.next_batch || Batch.create_placeholder(:release => self)
  end

  def pdc_type_validate_for_product
    if is_pdc?
      errors.add(:is_pdc, 'can\'t be set for an non PDC product. Change the product to support PDC first') \
                          if product && !product.supports_pdc?
      errors.add(:is_pdc, 'must be set for a PDC product') if !product
    end
  end

  def check_pdc_updates_allowed
    if !self.new_record?
      used_pdc_release_ids = pdc_release_ids_in_use
      current_pdc_releases_ids = pdc_releases.pluck(:id)
      if (current_pdc_releases_ids | used_pdc_release_ids) != current_pdc_releases_ids
        errors.add(:pdc_releases,
                   'cannot be removed from a is_pdc release when an advisory of this release is connected to it')
      end
    end
    if product_id_changed? && errata.any?
      errors.add(:product,
                 'cannot be modified for a is_pdc release when the release has an advisory')
    end
  end

  # When to create an is_pdc release, it need to set an supports_pdc Product,
  # and this Product should have been mapped to a PDC Product
  def pdc_product_exists
    unless product.pdc_product.present?
      errors.add(:is_pdc, 'can\'t be set for a non PDC product. Please make sure that the ET Product has been mapped to a PDC Product')
    end
  end

  def pdc_release_ids_in_use
    PdcRelease.joins(:errata).where("errata_main.group_id=?", self.id).pluck(:id)
  end

end
