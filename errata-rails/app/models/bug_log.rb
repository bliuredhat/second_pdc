class BugLog < RecordLog
  belongs_to :bug, :foreign_key => :record_id

  before_create :do_plain_log

  private
  def do_plain_log
    BUGLOG.send(severity.downcase, "Bug #{record_id}: #{message}")
  end
end
