module ThreadLocal
  # Allows the setting of a number of Thread.current variables for
  # the duration of a given block, and ensures Thread.current is
  # cleared out when the block returns or raises an error
  #
  # locals is expected to be a Hash
  def self.with_thread_locals(locals, &block)
    begin
      locals.each_pair {|k,v| Thread.current[k] = v}
      yield
    ensure
      locals.keys.each {|k| Thread.current[k] = nil}
    end
  end

  def self.get(k)
    Thread.current[k]
  end
end
