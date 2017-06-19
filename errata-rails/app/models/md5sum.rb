class Md5sum < ActiveRecord::Base
  include BrewChecksum

  def checksum_valid?
    return value && value =~ /^[a-f0-9]{32}$/
  end
end
