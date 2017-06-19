ActiveRecord::Base.class_eval do
  def self.transaction_with_retry(*args, &block)
    TransactionRetry.transaction_with_retry(*args, &block)
  end
end
