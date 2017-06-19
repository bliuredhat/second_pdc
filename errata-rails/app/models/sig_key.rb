# == Schema Information
#
# Table name: sig_keys
#
#  id                :integer       not null, primary key
#  name              :string        not null
#  keyid             :string        not null
#  sigserver_keyname :string        not null
#  full_keyid        :string        
#

class SigKey < ActiveRecord::Base
  def self.none_key
    SigKey.find_by_name 'none'
  end

  def self.default_key
    SigKey.find_by_name Settings.default_signing_key
  end
end
