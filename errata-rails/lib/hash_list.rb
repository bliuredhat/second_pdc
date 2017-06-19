class HashList < Hash
  def initialize
    super { |hash, key| hash[key] = [] }
  end

  def list_merge!(other)
    other.each_pair do |other_key, other_list|
      self[other_key] = Array.wrap(self[other_key]) + Array.wrap(other_list)
    end
    self
  end

  def list_merge_uniq!(other)
    other.each_pair do |other_key, other_list|
      self[other_key] = Array.wrap(self[other_key]) | Array.wrap(other_list)
    end
    self
  end

end
