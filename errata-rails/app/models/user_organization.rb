class UserOrganization < ActiveRecord::Base
  acts_as_tree :order => 'name'

  belongs_to :manager,
  :class_name => "User",
  :foreign_key => "manager_id"

  has_many :users

  scope :top_level_groups, where('parent_id IS NULL')

  before_create do
    self.manager = User.find_by_login_name('ship-list@redhat.com') unless self.manager
  end

  def self.all_children(parent)
    children = []
    children.concat(parent.children)
    parent.children.each { |c| children.concat(all_children(c))}

    return children
  end

  #
  # Which UserOrganizations can be considered devel groups?
  # Want to use this for a drop down select in filters.
  #
  # Note that we currently define an advisory's devel group as the package owner's
  # user organization (rather than the devel_responsibility field which would be
  # more sensible).
  #
  # I tried to write this with some AR joins and where methods but gave up. Perhaps
  # it can't be done...
  #
  def self.devel_groups
    self.find_by_sql "
      SELECT DISTINCT
        user_organizations.*
      FROM
        user_organizations,
        users,
        errata_main
      WHERE
        users.id = errata_main.package_owner_id
      AND
        user_organizations.id = users.user_organization_id
      ORDER BY
        user_organizations.name
    "
  end

  def to_s
    "#{name} [#{id}]"
  end

end
