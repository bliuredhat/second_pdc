module ShadowPush
  extend ActiveSupport::Concern

  included do
    validate :shadow_only_tasks

    before_create do
      set_shadow_defaults if pub_options['shadow']
    end
  end

  def set_shadow_defaults
    self.pre_push_tasks = self.valid_pre_push_tasks.select {|k,v| v[:shadow] && (v[:default] || v[:mandatory])}.collect {|v| v.first}
    self.post_push_tasks = self.valid_post_push_tasks.select {|k,v| v[:shadow] && (v[:default] || v[:mandatory])}.collect {|v| v.first}
    self.pub_options = self.valid_pub_options.select {|k,v| v[:default]}.inject({}) { |h, (k, v)| h[k] = true; h }
    self.pub_options['shadow'] = true
  end

  def shadow_only_tasks
    return unless pub_options['shadow']

    pre_push_tasks.each do |task_name|
      task = LivePushTasks::PRE_PUSH_TASKS[task_name]
      unless task && task[:shadow]
        errors.add(:tasks, "Task #{task_name} is not valid for shadow push.")
      end
    end
    post_push_tasks.each do |task_name|
      task = LivePushTasks::POST_PUSH_TASKS[task_name]
      unless task && task[:shadow]
        errors.add(:tasks, "Task #{task_name} is not valid for shadow push.")
      end
    end
  end

  def shadow_pub_options(description = nil)
    if errata.release.allow_shadow?
      {
        'shadow' => {
          :description => description,
        }
      }
    else
      {}
    end
  end
end
