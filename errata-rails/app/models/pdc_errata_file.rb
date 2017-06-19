class PdcErrataFile < ActiveRecord::Base

  def self.variant_id_field
    :pdc_variant_id
  end

  def self.variant_class_name
    'PdcVariant'
  end

  include ErrataFileCommon

  def is_pdc?
    true
  end

end
