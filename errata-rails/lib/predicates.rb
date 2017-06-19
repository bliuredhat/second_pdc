module Predicates
  # Returns a proc which returns true iff every passed proc returns
  # true.
  #
  # A nil proc is treated as "always true".
  def self.and(*procs)
    rest = procs.compact
    first = rest.shift
    if rest.empty?
      first || Predicates.true
    else
      lambda do |*args|
        next false unless first.call(*args)
        Predicates.and(*rest).call(*args)
      end
    end
  end

  # Returns a proc which always returns true.
  def self.true()
    lambda{|*args| true}
  end
end
