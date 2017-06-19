# fixture_helper may be used to easily write out some records into
# the appropriate fixture files.
#
# It adds a write_fixture! method onto ActiveRecord::Base, which may be used like this:
#
# $ rails c test
# > e = some_code_to_create_an_advisory
# > require 'test/fixture_helper'
# > e.write_fixture!  # advisory and its dependencies are now in the fixtures
#

# `rails c test' doesn't add test to the path by default
"#{Rails.root}/test".tap do |path|
  $: << path unless $:.include?(path)
end

module FixtureHelper
  def self.log(msg)
    Rails.logger.info msg
    $stderr.puts msg
  end

  # Bump the autoincrement for a table's primary key by a random
  # amount.  This makes it less likely for new fixtures introduced in
  # parallel to be assigned conflicting IDs.
  def self.bump_autoincrement(klass)
    # Only makes sense to do this in test env.  If using
    # fixture_helper to bring across data from the development env, we
    # want to keep the same IDs.
    return unless Rails.env.test?

    # some tables don't have any ID
    return unless klass.primary_key

    # some tables don't have any rows yet
    current_max = klass.pluck("MAX(#{klass.primary_key})").first || 0

    # Bump by a random amount.  Includes a scaled and unscaled
    # component which makes it work reasonably for both small and
    # large tables.
    scale = 1.01 + rand*0.02
    next_id = (scale*current_max).to_i + rand(10) + 30
    klass.connection.execute("ALTER TABLE #{klass.table_name} AUTO_INCREMENT = #{next_id}")
    self.log "Set #{klass.table_name}.#{klass.primary_key} autoincrement to #{next_id}"
  end

  # Bump the autoincrement on every table
  def self.bump_autoincrement_all
    ActiveRecord::Base.descendants.
      group_by(&:table_name).
      each do |table_name,(first_class,*other_classes)|
      # no need to repeat for classes sharing the same table...
      self.bump_autoincrement(first_class)
    end
  end
end

FixtureHelper.bump_autoincrement_all

require 'fixture_helper/base'
require 'fixture_helper/traverse'
