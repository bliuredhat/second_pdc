# == Schema Information
#
# Table name: carbon_copies
#
#  id        :integer       not null, primary key
#  errata_id :integer       not null
#  who       :integer       not null
#

class CarbonCopy < ActiveRecord::Base
#  set_table_name "errata_cc"

  belongs_to :errata

  belongs_to :who,
    :class_name => "User"

end
