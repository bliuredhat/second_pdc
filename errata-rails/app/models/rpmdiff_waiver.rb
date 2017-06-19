# == Schema Information
#
# Table name: rpmdiff_waivers
#
#  waiver_id   :integer       not null, primary key
#  result_id   :integer       not null
#  person      :integer       not null
#  description :text          not null
#  waive_date  :datetime      not null
#  old_result  :integer       not null
#

class RpmdiffWaiver < ActiveRecord::Base
  self.table_name = "rpmdiff_waivers"
  self.primary_key = "waiver_id"

  scope :acked, where(:acked => true)
  scope :not_acked, where(:acked => false)
  scope :latest_for_results, lambda{|results|
    # XXX workaround for this performance bug: http://bugs.mysql.com/bug.php?id=9021
    # Subquery prevents the index on result_id, waiver_id from being used, so if we're
    # passed a relation, inflate it here before passing to mysql.
    if results.kind_of?(ActiveRecord::Relation) && results.arel.engine == RpmdiffResult
      results = results.pluck(:result_id)
    end

    self.where(:result_id => results)\
      .where('waiver_id = (SELECT MAX(waiver_id) FROM rpmdiff_waivers w_inner WHERE w_inner.result_id=rpmdiff_waivers.result_id)')
  }

  before_create do
    self.waive_date = Time.now
    self.rpmdiff_test = self.rpmdiff_result.rpmdiff_test
    self.rpmdiff_run = self.rpmdiff_result.rpmdiff_run
    self.package = self.rpmdiff_result.rpmdiff_run.package
  end

  belongs_to :rpmdiff_score,
  :foreign_key => "old_result"

  belongs_to :user

  belongs_to :acked_by,
  :class_name => 'User',
  :foreign_key => "acked_by"

  belongs_to :rpmdiff_result,
  :foreign_key => "result_id"

  belongs_to :rpmdiff_run,
  :foreign_key => "run_id"

  belongs_to :rpmdiff_test,
  :foreign_key => "test_id"

  belongs_to :package

  def self.latest_waiver(package, test)
    RpmdiffWaiver.find(:first,
                       :conditions =>
                       ['old_result != 2 and package_id = ? and test_id = ?',
                       package, test],
                       :order => 'waive_date desc')
  end

  def self.waivers_for_errata(errata)
    RpmdiffWaiver.find(:all,
                       :conditions =>
                       ['old_result != 2 and run_id in (?)',
                        errata.rpmdiff_runs],
                       :order => 'waive_date desc',
                       :include => [:user, :rpmdiff_test])
  end

  def can_ack?(user = User.current_user)
    user.can_ack_rpmdiff_waiver?
  end

  # nacking a waiver can be done by whoever can ack but also can be done by
  # whoever could have requested the waiver in the first place - e.g. if
  # they realize they're mistaken.
  def can_nack?(user = User.current_user)
    can_ack?(user) || self.rpmdiff_result.can_waive?(user)
  end

  def ack!(opts = {})
    opts = {:user => User.current_user}.merge(opts)
    user = opts[:user]
    raise "User #{user} doesn't have permission to ack" unless can_ack?(user)
    self.acked = true
    self.acked_by = user
    self.ack_description = opts[:text]
    self.save!
  end

  # nack is equivalent to unwaive
  def nack!(opts = {})
    opts = {:user => User.current_user}.merge(opts)

    user = opts[:user]
    raise "User #{user} doesn't have permission to nack" unless can_nack?(user)

    text = opts[:text]
    raise "Missing mandatory nack text" if text.blank?

    waiver = RpmdiffWaiver.where(:result_id => self.rpmdiff_result).order('waiver_id DESC').limit(1).first
    raise "Waiver #{self.id} can't be nacked because there is a newer waiver #{waiver.id} for this RPMDiff result" if waiver != self

    raise "Waiver #{self.id} can't be nacked because it is an un-waive" if self.is_unwaive?

    result = RpmdiffResult.find(self.result_id)
    ActiveRecord::Base.transaction do
      result.rpmdiff_waivers.create!(
        :user => user,
        :description => text,
        :old_result => result.score)
      result.score = self.old_result
      result.save!
    end
  end

  def is_unwaive?
    old_result == RpmdiffScore::WAIVED
  end

  def person
    return self.user
  end
end
