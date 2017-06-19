require 'delegate'
# Wraps a Delayed::Job to provide friendlier information
class DelayedJobExhibit < SimpleDelegator
  def status
    if locked_by?
      'RUNNING'
    elsif last_error?
      'FAILED'
    else
      'QUEUED'
    end
  end

  def task_name
    pl = payload_object
    if pl.respond_to?(:task_name)
      pl.task_name
    elsif pl.is_a? Delayed::PerformableMethod
      "#{pl.object.gsub('CLASS:','')}.#{pl.method} #{pl.args.join(', ')}"
    else
      pl.class.to_s
    end
  end

  def error
    # Delayed::Job stuffs the exception message and backtrace into
    # last_error and throws away all other info.  That includes the
    # exception class unfortunately, so we can't do something smart
    # using the class to get the user-presentable error.  Just show
    # everything up to the first line of backtrace.
    error_str = last_error
    return if error_str.blank?

    out = []
    error_str.lines.each do |line|
      break if line =~ %r{^/.*\.rb:\d+:in }
      out << line
    end
    out.join.chomp
  end

  # Seems like the id method is not passed to
  # the delegator object so let's do this.
  def id
    __getobj__.id
  end
end
