#
# Make delayed job send an email notification when a job
# throws an exception.
#
Delayed::Job.class_eval do

  def log_exception_with_notification(exception)
    log_exception_without_notification(exception)
    ExceptionNotifier.notify_exception(exception, :data => {
      # This extra info will be included in the email
      :system_hostname => ErrataSystem::SYSTEM_HOSTNAME,
      :job => self,
      :handler => self.handler,
      :last_error => self.last_error,
    })
  end
  alias_method_chain :log_exception, :notification

end
