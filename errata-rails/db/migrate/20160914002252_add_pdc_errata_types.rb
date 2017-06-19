class AddPdcErrataTypes < ActiveRecord::Migration
  def up
    ActiveRecord::Base.transaction do
      ErrataType.create!(name: 'PdcRHBA', description: 'Red Hat Bug Fix Advisory (PDC)')
      ErrataType.create!(name: 'PdcRHEA', description: 'Red Hat Enhancement Advisory (PDC)')
      ErrataType.create!(name: 'PdcRHSA', description: 'Red Hat Security Advisory (PDC)')
    end
  end

  def down
    # may fail if there are records associated with the
    # new PdcErrata Types
    ActiveRecord::Base.transaction do
      %w(PdcRHBA PdcRHEA PdcRHSA).each do |et_type|
        ErrataType.find_by_name(et_type).destroy
      end
    end
  end
end
