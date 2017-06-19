class AddActiveToErrataArches < ActiveRecord::Migration
  def self.up
    add_column :errata_arches, :active, :boolean, :null => false, :default => true

    active_arches = ['i386','ia64','ppc','ppc64','s390','s390x','x86_64']
    Arch.where('name not in (?)', active_arches).update_all('active = 0')
  end

  def self.down
    remove_column :errata_arches, :active
  end
end
