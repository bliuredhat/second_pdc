namespace :debug do
  namespace :ftp_excl_rules do

    #
    # To get what combinations or package/product_version there are look
    # in ErrataBrewMapping table. (Is there a better way?)
    #
    # (This is kind of similar to FtpExclusion.search_by_pkg_prod_ver_or_prod)
    #
    def get_all_pv_pkgs
      # I'm doing this with sql since I think the distinct might be quicker..
      sql = "
        SELECT DISTINCT
          product_version_id,
          package_id
        FROM
          errata_brew_mappings
      "
      ErrataBrewMapping.find_by_sql(sql).map { |row|
        # Note: row here is not a proper ErrataBrewMapping. Just using the columns we fetched.
        [ProductVersion.find(row.product_version_id), Package.find(row.package_id)]
      }.sort_by{ |pv,pkg|
        # Sort just so the report shows them in some defined order and can be diffed, etc
        [pv.product.name, pv.name, pkg.name]
      }
    end

    #
    # A big long list showing every product_version/package and it's exclusion status.
    # It shows if it's excluded or not but does not show details about why it's excluded.
    #
    desc "Show all ftp exclusion details"
    task :show_all_excl => :environment do
      get_all_pv_pkgs.each do |pv,pkg|
        puts "#{FtpExclusion.is_excluded?(pkg,pv).present? ? "EXCLUDE" : "publish"} #{pv.product.short_name}/#{pv.name}/#{pkg.name}"
      end
    end

    #
    # A big long list showing every product_version/package with details on if (and why)
    # it's excluded from publishing srpms to public ftp.
    #
    desc "Show all ftp exclusion details"
    task :show_all_excl_details => :environment do
      # Show the exclusion and the reason for it
      get_all_pv_pkgs.each do |pv,pkg|
        puts "#{"%-50s"%FtpExclusion.show_exclude_rules(pkg,pv)} #{pv.product.short_name}/#{pv.name}/#{pkg.name}"
      end
    end

  end
end
