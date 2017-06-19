class ErrataLogger < Logger
  LOGFILE_PREFIX = ENV['LOGFILE_PREFIX'] ? "#{ENV['LOGFILE_PREFIX']}-" : ""

  # The name of the log is retained for test/debug purposes only.
  attr_accessor :name

  def self.new(name, opts={})
    log_level = opts.fetch :level, INFO
    keep_files = opts.fetch :keep_files, 10
    max_file_size = opts.fetch :max_file_size, 100000000
    new_logger = super("#{Rails.root}/log/#{LOGFILE_PREFIX}#{name}.log", keep_files, max_file_size)
    new_logger.name = name
    # Support log tagging.
    #
    # Rails would do this by default if we let it create the logger, but since
    # we explicitly create loggers, we need to wrap it ourselves.
    new_logger = ActiveSupport::TaggedLogging.new(new_logger)
    new_logger.level = log_level
    new_logger
  end

  def format_message(severity, timestamp, progname, msg)
    "[#{timestamp.strftime("%Y-%m-%d %H:%M")}] #{severity} " +
      (progname ? "(#{progname})" : "") +
      " #{msg}\n"
  end
end
