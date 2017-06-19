# == Schema Information
#
# Table name: rpmdiff_tests
#
#  test_id     :integer       not null, primary key
#  description :string(240)   not null
#  long_desc   :string(240)   not null
#  wiki_url    :string(240)   not null
#

class RpmdiffTest < ActiveRecord::Base
  self.primary_key = 'test_id'
end
