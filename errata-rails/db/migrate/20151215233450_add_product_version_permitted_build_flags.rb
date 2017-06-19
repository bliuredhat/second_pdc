class AddProductVersionPermittedBuildFlags < ActiveRecord::Migration
  def change
    add_column :product_versions, :permitted_build_flags, :string
    ProductVersion.reset_column_information
  end
end
