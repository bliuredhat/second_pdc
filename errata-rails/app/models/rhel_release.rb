# == Schema Information
#
# Table name: rhel_releases
#
#  id          :integer       not null, primary key
#  name        :string        not null
#  description :string        
#

class RhelRelease < ActiveRecord::Base
  validates_uniqueness_of :name
  validates_presence_of :name, :description

  has_many :product_versions
  has_many :variants

  scope :by_name, :order => 'name ASC'

  # Returns RHEL version number, i.e. 3 for RHEL 3
  # Will likely need revisited for z-stream
  def version_number
    self.name =~ /RHEL-([0-9]+)/
    return $1.to_i
  end

  def is_zstream?
    (self.name =~ /Z$/i) != nil
  end

  def main_stream
    ['RHEL', self.version_number].join('-')
  end

  # Going to allow admins to delete a RHEL release but only if it
  # hasn't been used for anything.
  def delete_ok?
    product_versions.empty? && variants.empty?
  end
end
