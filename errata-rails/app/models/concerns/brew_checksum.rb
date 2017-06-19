module BrewChecksum
  extend ActiveSupport::Concern

  included do
    belongs_to :sig_key
    belongs_to :brew_file

    validates_uniqueness_of :value, :on => :create, :message => lambda{|error,attrs|
      "#{attrs[:value]} has already been taken (duplicate #{attrs[:model]})"
    }

    def self.brew_file_checksum(brew_file, sig_key)
      self.find_by_brew_file_id_and_sig_key_id(brew_file, sig_key)
    end
  end
end
