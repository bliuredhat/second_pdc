# == Schema Information
#
# Table name: errata_products
#
#  id          :integer       not null, primary key
#  name        :string(2000)  not null
#  description :string(2000)  not null
#  path        :string(4000)
#  ftp_path    :string(4000)
#  build_path  :string(4000)
#  short_name  :string(255)
#  isactive    :integer       default(1), not null
#  ftp_subdir  :string
#

class Product < ActiveRecord::Base
  self.table_name = "errata_products"

  include FindByIdOrName
  include CanonicalNames

  has_many  :errata
  has_many :variants
  has_many :product_versions,
  :conditions => 'enabled = 1'

  has_many :active_releases,
  :class_name => 'Release',
  :conditions => 'enabled = 1 and isactive = 1'

  has_many :releases

  belongs_to :default_solution
  belongs_to :state_machine_rule_set
  belongs_to :pdc_product

  has_many :allowable_push_targets
  has_many :push_targets,
  :through => :allowable_push_targets

  has_many :brew_rpm_name_prefixes

  scope :supports_pdc, where(:supports_pdc => true)

  validates_presence_of :default_solution, :valid_bug_states, :name, :description, :short_name, :state_machine_rule_set
  validates_uniqueness_of :name, :short_name
  validate :no_active_pdc_releases

  def self.active_products(sort_column = 'name')
    self.where('isactive = 1').order(sort_column)
  end

  def self.exclude_ids(id_list)
    # self.scoped means do nothing but return the right class for chaining AREL scopes
    id_list.empty? ? self.scoped : self.where("id NOT IN (?)", id_list)
  end

  before_save do
    # Don't want spaces or empty strings in cdw_flag_prefix. Convert them to nil.
    self[:cdw_flag_prefix] = nil if self[:cdw_flag_prefix] && self[:cdw_flag_prefix].strip.blank?
  end

  # Make it easy to maintain these things
  def add_brew_rpm_name_prefix(*prefixes)
    prefixes.flatten.each do |prefix_text|
      prefix = brew_rpm_name_prefixes.find_or_create_by_text(prefix_text)
      self.brew_rpm_name_prefixes << prefix unless self.brew_rpm_name_prefixes.include?(prefix)
    end
  end

  def brew_rpm_name_prefix_strings
    self.brew_rpm_name_prefixes.order('text').map(&:text)
  end

  def allow_ftp?
    self.push_targets.map(&:push_type).include? :ftp
  end

  def notify_partners?
    is_extras? || is_rhel?
  end

  def valid_bug_states
    read_attribute(:valid_bug_states).split(',').collect {|v| v.strip}
  end

  def is_extras?
    'LACD' == self.short_name
  end

  def is_rhel?
    'RHEL' == self.short_name
  end

  def is_end_to_end_test?
    self.short_name.in?(Settings.end_to_end_test_products)
  end

  def ftp_subdir
    subdir = read_attribute('ftp_subdir')
    if subdir.blank?
      subdir = self.short_name
    end
    return subdir
  end

  def long_name
    "#{self.name} (#{self.short_name})"
  end

  def no_active_pdc_releases
    if !supports_pdc? && active_releases.pdc.any?
      errors.add(:supports_pdc, 'cannot be disabled when product has associated PDC releases that are active')
    end
    if pdc_product_id_changed? && active_releases.pdc.any?
      errors.add(:pdc_product,
                 'cannot modify PDC product when product has associated PDC releases that are active')
    end
  end

  def can_change_supports_pdc?
    return !(supports_pdc? && active_releases.pdc.any?)
  end

end
