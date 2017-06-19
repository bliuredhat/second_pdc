class Sha256sum < ActiveRecord::Base
  include BrewChecksum

  def checksum_valid?
    return value && value =~ /^[a-f0-9]{64}$/
  end
end
