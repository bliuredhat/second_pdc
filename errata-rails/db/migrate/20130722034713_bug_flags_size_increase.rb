# See Bug 986748.
# Need more than 255 chars for bug flags sometimes.
# :text has max 65535 chars (text in mysql)
# :string has max 255 chars (varchar(255) in mysql)
class BugFlagsSizeIncrease < ActiveRecord::Migration
  def self.up
    change_column :bugs, :flags, :text
  end

  def self.down
    change_column :bugs, :flags, :string
  end
end
