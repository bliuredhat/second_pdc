class RhtsRun < ActiveRecord::Base
  belongs_to :errata
  belongs_to :user
end
