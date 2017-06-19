class RecordLog < ActiveRecord::Base
  extend DefineClassMethod

  SEVERITIES = %w{DEBUG INFO WARN ERROR FATAL UNKNOWN}

  belongs_to :record
  belongs_to :user

  validates :severity, :inclusion => {:in => SEVERITIES}

  private
  def self.inherited(subclass)
    super(subclass)
    add_log_class_methods(subclass)
    add_error_log_method(subclass)
    add_define_log_methods_method(subclass)
  end

  # add the info, debug etc class methods to a subclass
  def self.add_log_class_methods(subclass)
    SEVERITIES.map(&:downcase).each do |severity|
      subclass.define_class_method(severity) do |record, message|
        record_id = record.try(:id) || record.to_i
        subclass.create!(
          :record_id => record_id,
          :severity => severity.upcase,
          :message => message,
          :user => User.display_user
        )
      end
    end
  end

  def self.add_error_log_method(subclass)
    subclass.define_class_method(:with_error_log) do |record,message,&block|
      begin
        block.call()
      rescue XMLRPC::FaultException => e
        subclass.error(record, "#{message}: #{e.class}: #{e}")
        raise e
      rescue StandardError => e
        subclass.error(record, "#{message}: #{e.class}")
        raise e
      end
    end
  end

  # SomeRecordLogSubclass.define_log_methods(SomeRecord) enables logging
  # directly from the target record, e.g.
  #  SomeRecord.where(foo).first.info 'Something happened...'
  def self.add_define_log_methods_method(subclass)
    subclass.define_class_method(:define_log_methods) do |targetclass|
      (SEVERITIES.map(&:downcase) << 'with_error_log').each do |method|
        targetclass.send(:define_method, method) do |*args,&block|
          subclass.send(method, self, *args, &block)
        end
      end
    end
  end

end
