class ExternalTestType < ActiveRecord::Base
  include ActiveInactive

  # External test types can be grouped by naming convention.
  # Such types will be grouped together in certain contexts, e.g. when
  # listing the results for an advisory.
  #
  # This example demonstrates the meaning of the following methods.
  #
  # +---------+------------------+------------+------------------+
  # | name    |  toplevel_name   |  subname   |   related        |
  # +---------+------------------+------------+------------------+
  # | foo     |  foo             |            | foo/bar, foo/baz |
  # | foo/bar |  foo             |  bar       | foo, foo/baz     |
  # | foo/baz |  foo             |  baz       | foo, foo/bar     |
  # | bar     |  bar             |            |                  |
  # +---------+------------------+------------+------------------+

  # Returns only top-level test types, e.g. will return "ccat" and will not
  # return "ccat/manual".
  scope :toplevel, where('name not like "%/%"')

  before_create do
    self.tab_name ||= name.titleize
  end

  # For convenience
  def self.get(name_or_object)
    (name_or_object.is_a?(ExternalTestType) ||
     name_or_object.is_a?(ActiveRecord::Relation) ||
     name_or_object.is_a?(Array)) ?
      name_or_object :
      find_by_name(name_or_object.to_s)
  end

  def run_url_template
    Rails.env.production? ? prod_run_url : test_run_url
  end

  def toplevel_name
    name.split('/', 2).first
  end

  def subname
    name.split('/', 2).second
  end

  # Returns a relation of this external test type in addition to any other
  # external test types under the same namespace.
  def with_related_types
    ExternalTestType.
      unscoped.
      where('name = ? or name like ?', toplevel_name, "#{toplevel_name}/%")
  end

  # As above, for a relation.
  # Returns the union of with_related_types for each type in the relation.
  def self.with_related_types
    related_ids = scoped.map{|type| type.with_related_types.pluck('id')}.flatten
    unscoped.where(:id => related_ids)
  end

  def to_s
    display_name
  end

  def reschedule_supported?
    name.in? %w(covscan ccat)
  end

end
