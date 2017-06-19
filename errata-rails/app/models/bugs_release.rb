class BugsRelease < ActiveRecord::Base
  belongs_to :release
  belongs_to :bug
end
