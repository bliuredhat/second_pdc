# == Schema Information
#
# Table name: tpsstates
#
#  id    :integer       not null, primary key
#  state :string(255)   not null
#

class TpsState < ActiveRecord::Base
  self.table_name = "tpsstates"

  has_many :tps_jobs,
  :foreign_key => "state_id",
  :conditions => "rhnqa = 0",
  :include => [:run, :arch, :variant, :tps_state],
  :order => 'version_id, arch_id'

  has_many :rhnqa_jobs,
  :class_name => "TpsJob",
  :foreign_key => "state_id",
  :conditions => "rhnqa = 1",
  :include => [:run, :arch, :variant, :tps_state],
  :order => 'version_id, arch_id'


  # Constant scores
  NOT_STARTED = 1
  INVALIDATED = 2
  PENDING = 3
  BUSY = 4
  GOOD = 5
  BAD = 6
  INFO = 7
  VERIFY = 8
  WAIVED = 9
  NOT_SCHEDULED = 99

  # Example usage tps_state.state_is?('NOT_STARTED')
  def is_state?(state_string)
    self.state == state_string.to_s.upcase
  end

  def is_completed_state?
    ['GOOD', 'WAIVED', 'BAD', 'INFO', 'VERIFY'].include?(self.state)
  end

  def self.default
    NOT_SCHEDULED
  end
end
