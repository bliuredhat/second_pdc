class BrewTagsRelease < ActiveRecord::Base
  belongs_to :release
  belongs_to :brew_tag
end
