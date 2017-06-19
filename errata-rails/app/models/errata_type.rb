# == Schema Information
#
# Table name: errata_types
#
#  id          :integer       not null, primary key
#  name        :string(20)
#  description :string(255)
#

class ErrataType < ActiveRecord::Base
  # NB: This needs to be udpated if another type is added.
  # (Don't want to fetch these from the db here).
  ALL_TYPES = %w[RHBA RHEA RHSA PdcRHBA PdcRHEA PdcRHSA]
  ALL_SHORT_TYPES = %w[RHBA RHEA RHSA]
  NON_PDC_TYPES = %w[RHBA RHEA RHSA]
  PDC_TYPES = %w[PdcRHBA PdcRHEA PdcRHSA]

  scope :pdc, ->{where(name: PDC_TYPES)}
  scope :legacy, ->{where(name: NON_PDC_TYPES)}

  def short_desc
    description.gsub(/(^Red Hat | Advisory$)/,'')
  end
end
