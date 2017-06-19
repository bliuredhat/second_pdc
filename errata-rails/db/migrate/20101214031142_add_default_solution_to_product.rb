class AddDefaultSolutionToProduct < ActiveRecord::Migration
  def self.up
    create_table :default_solutions do |t|
      t.string  :title, :null => false
      t.text  :text, :null => false
    end
    add_column :errata_products, :default_solution_id, :integer
    add_foreign_key "errata_products", ["default_solution_id"], "default_solutions", ["id"]
    
    default_text = <<END_OF_STRING
Before applying this update, make sure all previously released errata
relevant to your system have been applied.

To update all RPMs for your particular architecture, run:

rpm -Fvh [filenames]

where [filenames] is a list of the RPMs you wish to upgrade.  Only those
RPMs which are currently installed will be updated.  Those RPMs which are
not installed but included in the list will not be updated.  Note that you
can also use wildcards (*.rpm) if your current directory *only* contains the
desired RPMs.

Please note that this update is also available via Red Hat Network.  Many
people find this an easier way to apply updates.  To use Red Hat Network,
launch the Red Hat Update Agent with the following command:

up2date

This will start an interactive process that will result in the appropriate
RPMs being upgraded on your system.
END_OF_STRING

    enterprise_text = <<END_OF_STRING
Before applying this update, make sure all previously-released errata
relevant to your system have been applied.

This update is available via the Red Hat Network. Details on how to
use the Red Hat Network to apply this update are available at
http://kbase.redhat.com/faq/docs/DOC-11259
END_OF_STRING

    default = DefaultSolution.create(:title => 'default', :text => default_text)
    enterprise = DefaultSolution.create(:title => 'enterprise', :text => enterprise_text)
    
    Product.update_all ['default_solution_id = ?', default], "name not like '%Enterprise%'"
    Product.update_all ['default_solution_id = ?', enterprise], "name like '%Enterprise%'"
  end

  def self.down
    remove_column :errata_products, :default_solution_id
    drop_table :default_solutions
  end
end
