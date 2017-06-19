class Role < ActiveRecord::Base
  validates_uniqueness_of :name

  has_and_belongs_to_many :users,
  :order => "login_name"

  # The readonly-admin role is obsoleted by bug 1156386
  default_scope { where("name != 'readonly-admin'") }

  scope :all_except_readonly, where("name != 'readonly'")

  def is_special?
    %w[errata readonly].include?(name)
  end

  def is_hidden?
    %w[super-user].include?(name)
  end

  def is_normal?
    !is_special? && !is_hidden?
  end

  def self.qa_people
    find_in_group('qa')
  end

  def self.devel_people
    find_in_group('devel')
  end

  def self.docs_people
    find_in_group('docs')
  end

  def self.signers
    find_in_group('signer')
  end

  def self.management_people
    find_in_group('management')
  end

  def self.find_in_group(name)
    find_by_name(name).users
  end

  def title_name
    name.titleize
  end

  def pretty_name
    team_name || "#{title_name} role"
  end

  def long_title_name
    "#{title_name}#{' (all users)' if name == 'errata'}"
  end

  def rt_full_email
    "#{rt_email}@redhat.com" if rt_email.present?
  end

end
