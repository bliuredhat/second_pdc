# == Schema Information
#
# Table name: users
#
#  id         :integer       not null, primary key
#  login_name :string(255)   not null
#  realname   :string(255)   not null
#

class User < ActiveRecord::Base
  include UserPermissions

  # Keep user prefs in a serialized hash so we can easily
  # add them without doing a migration
  serialize :preferences, Hash

  require 'set'

  has_and_belongs_to_many :roles

  has_many :assigned_errata,
  :class_name => "Errata",
  :foreign_key => "assigned_to_id"

  has_many :reported_errata,
  :class_name => "Errata",
  :foreign_key => "reporter_id"

  has_many :carbon_copies,
  :foreign_key => "who_id"

  has_many :devel_errata,
  :class_name => "Errata",
  :foreign_key => "package_owner_id"

  has_many :observed_errata,
  :through => :carbon_copies,
  :source => :errata

  has_many :errata_activities,
  :foreign_key => "who_id"

  belongs_to :organization,
  :foreign_key => 'user_organization_id',
  :class_name => "UserOrganization"

  has_many :user_errata_filters

  # This should return nil if they don't have one
  def default_filter
    if preferences && preferences[:default_filter_id] && ErrataFilter.exists?(:id=>preferences[:default_filter_id])
      ErrataFilter.find(preferences[:default_filter_id])
    else
      SystemErrataFilter.default
    end
  end

  # Let's try some new style scopes...
  scope :enabled,  where(:enabled => true)
  scope :disabled, where(:enabled => false)
  scope :enabled_or_current, lambda { |current| where('enabled = 1 OR id = ?', current) }
  scope :by_name, order('users.realname ASC')

  # Used in app/models/notifier to supress emails to users that are no longer here.
  # (Note: This allows mails to disabled users, which seems kind of wrong, but we need
  # it because users such as partner-testing@redhat.com are disabled (indicating that
  # they can't login), but need to be able to get emails).
  scope :can_mailto, where(:receives_mail => true)

  # Not actually using these ones yet...
  scope :with_role, lambda { |role_name| joins(:roles).where('roles.name = ?', role_name) }
  scope :managers, enabled.with_role('management')
  scope :admin,    enabled.with_role('admin')

  before_create do
    last_id = User.maximum :id
    last_id ||= 0
    self.id = last_id + 1
    unless self.organization
      self.organization = UserOrganization.find_by_name('Engineering')
    end
  end

  validates :login_name, :presence => true
  validates_uniqueness_of :login_name
  validates :realname, :presence => true

  def User.all_reporters
    User.where('id in (select distinct reporter_id from errata_main)').order('login_name')
  end

  def organization_name
    self.organization ? self.organization.name : nil
  end

  def check_role_auth(fail_msg, *roles_to_check)
    raise fail_msg unless in_role?(*roles_to_check)
  end

  def in_role?(*roles_to_check)
    return true if roles.detect {|r| roles_to_check.include?(r.name)}
    return false
  end

  # Return true if the user is marked as the manager of their organization
  def is_manager?
    organization && organization.manager == self
  end

  # No role users are treated as if they have readonly role (Bz 994808)
  def is_readonly?
    in_role?('readonly') || has_no_role?
  end

  # Low budget kernel developer detection:
  #  Consider the user kernel developer if they are a developer and they either work
  #  in a kernel related org unit or, created a kernel related advisory recently.
  def is_kernel_developer?
    in_role?('devel') && (
      organization.name =~ /kernel/i ||
      reported_errata.where("synopsis like '%kernel%' AND created_at > ?", 18.months.ago).any?
    )
  end

  # It actually means "has no role except for the errata role".
  # (The 'errata' role is kind of useless since everyone has it,
  # but I don't want to remove it just yet).
  def has_no_role?
    self.roles.where("name != 'errata'").empty?
  end

  def replace_roles(*role_names)
    self.roles = Role.where(:name => role_names.flatten.uniq)
  end

  def add_roles(*role_names)
    self.roles << Role.where(:name => role_names.flatten.uniq).reject{ |role| self.roles.include?(role) }
  end
  alias_method :add_role, :add_roles

  def remove_roles(*role_names)
    self.roles = self.roles.reject{ |role| role_names.flatten.include?(role.name) }
  end
  alias_method :remove_role, :remove_roles

  # We want to distinguish default owners that are real people
  # from default owners that are mailing lists.
  # It just so happens that "real people" don't have a '-' char
  # in their username/email address, but mailing lists do.
  # (This is a temporary hack for Bug 883179 until we have a
  # better solution).
  def probably_mailing_list?
    !!short_name.match(/\-/)
  end

  def short_name
    (login_name =~ /(.+)\@/) ? $1 : login_name
  end

  def url_name
    return short_name
  end

  def email
    return email_address.present? ? email_address : login_name
  end

  # The reason (I think) for the default user is for offline stuff,
  # eg delayed job tasks where we aren't coming via the web UI.
  # (But it seems a bit confusing, refactor maybe)
  def User.current_user
    Thread.current[:current_user] || default_qa_user
  end

  # Want a version of User.current_user that doesn't
  # fallback to a default user. Will use it in main_layout.
  def User.display_user
    Thread.current[:current_user]
  end

  def User.default_docs_user
    @@default_docs_user ||= User.find_by_login_name(MAIL['default_docs_user'])
  end

  def User.default_qa_user
    @@default_qa_user ||= User.find_by_login_name(MAIL['default_qa_user'])
  end

  def User.fake_devel_user
    return nil unless Rails.env.development?
    @@fake_devel_user ||= User.find_by_login_name(Settings.fake_devel_login_name) || User.create(
      :login_name => Settings.fake_devel_login_name,
      :realname   => 'Devel User',
      :roles      => Role.all_except_readonly
    )
  end

  # Returns the errata system's credentials for internal
  # transitions and authentication
  def User.system
    @@system_user ||= User.find_by_realname 'Errata System'
  end

  def User.find_by_name(name)
    email = "#{name}@redhat.com"
    return User.find_by_login_name(email) || User.find_by_login_name(name)
  end

  def User.make_from_login_name(name)
    user = User.find_by_login_name(name)
    unless user
      user = User.make_from_rpc(name)
    end
    return user
  end

  def to_s
    "#{realname} (#{login_name})"
  end

  def short_to_s
    "#{realname} (#{short_name})"
  end

  def old_values
    return {} if self.new_record?

    the_changes = self.changes

    if the_changes[:enabled]
      the_changes[:enabled].map!(&:to_bool)
    end

    if the_changes[:user_organization_id]
     the_changes[:organization] = the_changes[:user_organization_id].map{|val| UserOrganization.find(val).name}
     the_changes.delete(:user_organization_id)
    end
    the_changes
  end

  def enabled_txt
    return "enabled" if self.enabled?
    return "disabled"
  end
end
