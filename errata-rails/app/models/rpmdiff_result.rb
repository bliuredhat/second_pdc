# == Schema Information
#
# Table name: rpmdiff_results
#
#  result_id      :integer       not null, primary key
#  run_id         :integer       not null
#  test_id        :integer       not null
#  score          :integer       not null
#  log            :text          not null
#  need_push_priv :integer       default(0), not null
#

class RpmdiffResult < ActiveRecord::Base
  self.table_name = "rpmdiff_results"
  self.primary_key = 'result_id'

  belongs_to :rpmdiff_test,
    :foreign_key => "test_id"

  belongs_to :rpmdiff_run,
    :foreign_key => "run_id"

  belongs_to :rpmdiff_score,
    :foreign_key => "score"

  has_many :rpmdiff_waivers,
  :foreign_key => 'result_id',
  :order => "waive_date asc"

  has_many :rpmdiff_result_details,
    :foreign_key => 'result_id'

  scope :waivable, :conditions => ['score IN (?)', [RpmdiffScore::NEEDS_INSPECTION, RpmdiffScore::FAILED]]

  after_update do
    if @score_changed
      run = self.rpmdiff_run
      run.overall_score = RpmdiffResult.maximum(:score,
                                                :conditions =>
                                                "run_id = #{run.run_id}")
      run.save!
    end
  end

  def can_waive?(user = User.current_user)
    return false if user.is_readonly?
    roles = waiver_roles
    roles.empty? || user.in_role?(*roles)
  end

  def log
    unclean = read_attribute(:log)
    return '' if unclean.blank?
    CGI.unescapeElement(CGI.escapeHTML(unclean), 'table', 'tr', 'td', 'tt', 'pre', 'b').gsub('&amp;', '&')
  end

  def score=(new_score)
    unless self.score == new_score
    write_attribute(:score, new_score)
      @score_changed = true
    end
  end

  def waivable?
    [RpmdiffScore::NEEDS_INSPECTION, RpmdiffScore::FAILED].include?(self.score)
  end

  def latest_waiver
    RpmdiffWaiver.latest_waiver(rpmdiff_run.package_id, test_id)
  end

  def waiver_roles
    return [] if can_approve_waiver.blank?
    can_approve_waiver.split('|')
  end

end
