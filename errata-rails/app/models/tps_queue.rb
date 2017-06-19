require 'tps/job_queue'
class TpsQueue
  def self.schedule_publication
    return if Delayed::Job.exists?(["handler like ?", "%#{self.to_s}%"])
    TpsQueue.send_prioritized(15, :publish)
  end

  def self.publish
    Tps.publish_job_queue
  end
end
