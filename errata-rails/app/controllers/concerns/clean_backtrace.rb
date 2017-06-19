module CleanBacktrace

  protected

  # Strips all the non-rails root bits out of log
  # Don't need to see dozens of lines of mongrel and rails source
  # for ET errors
  def clean_backtrace(exception)
    if Object.const_defined?(:Rails)
      root = File.expand_path(Rails.root)
      return exception.backtrace.select { |line| line.include?(root) }
    else
      return exception.backtrace
    end
  end

end
