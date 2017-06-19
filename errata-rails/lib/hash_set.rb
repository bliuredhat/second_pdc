#
# A hash of sets
#
# See also lib/hash_list
#
class HashSet < Hash
  def initialize
    super { |hash, key| hash[key] = Set.new }
  end
end
