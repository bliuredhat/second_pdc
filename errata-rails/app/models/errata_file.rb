class ErrataFile < ActiveRecord::Base
  def self.variant_id_field
    :version_id
  end

  def self.variant_class_name
    'Variant'
  end

  include ErrataFileCommon

  def is_pdc?
    false
  end

end
