class CreateBrewRpmNamePrefixes < ActiveRecord::Migration
  def self.up
    create_table :brew_rpm_name_prefixes do |t|
      t.string :text, :null => false
      t.references :product, :null => false
      t.timestamps
    end

    # Add some prefixes that we know about so far
    {
      'RHSCL' => %w[
        mariadb55
        mysql55
        nodejs010
        perl516
        php54
        postgresql92
        python27
        python33
        ruby193
      ],

      'RHDevToolset' => %w[
        devtoolset-2
      ]

    }.each_pair do |product_name, prefixes|
      Product.find_by_short_name(product_name).try(:add_brew_rpm_name_prefix, prefixes)
    end

  end

  def self.down
    drop_table :brew_rpm_name_prefixes
  end
end
