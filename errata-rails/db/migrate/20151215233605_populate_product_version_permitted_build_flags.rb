class PopulateProductVersionPermittedBuildFlags < ActiveRecord::Migration
  def up
    # Currently, RHEL-6 and RHEL-7 can use buildroot-push, and nothing else has any effect.
    ProductVersion.
      where(:name => %w[RHEL-6 RHEL-7]).
      update_all(:permitted_build_flags => Set.new(['buildroot-push']).to_yaml)
  end

  def down
    # No attempt to undo data change
  end
end
