#
# Currently there is no way to create them via the UI.
# This should be addressed by bug 1091806.
#
namespace :add_cdn_repo_links do

  # See https://engineering.redhat.com/rt/Ticket/Display.html?id=299579
  desc "Add cdn repo links for RHEL-7.0.Z-Supplementary"
  task :for_rhel_70z_supp => :environment do
    do_create_cdn_repo_links([

      ['7Client-7.0.Z-Client', %w[
        rhel-7-desktop-supplementary-debuginfo__7Client__x86_64
        rhel-7-desktop-supplementary-rpms__7Client__x86_64
        rhel-7-desktop-supplementary-source-rpms__7Client__x86_64
      ]],

      ['7ComputeNode-7.0.Z-ComputeNode', %w[
        rhel-7-for-hpc-node-supplementary-debuginfo__7ComputeNode__x86_64
        rhel-7-for-hpc-node-supplementary-rpms__7ComputeNode__x86_64
        rhel-7-for-hpc-node-supplementary-source-rpms__7ComputeNode__x86_64
      ]],

      ['7Server-7.0.Z-Server', %w[
        rhel-7-for-power-supplementary-debuginfo__7Server__ppc64
        rhel-7-for-power-supplementary-rpms__7Server__ppc64
        rhel-7-for-power-supplementary-source-rpms__7Server__ppc64

        rhel-7-for-system-z-supplementary-debuginfo__7Server__s390x
        rhel-7-for-system-z-supplementary-rpms__7Server__s390x
        rhel-7-for-system-z-supplementary-source-rpms__7Server__s390x

        rhel-7-server-supplementary-debuginfo__7Server__x86_64
        rhel-7-server-supplementary-rpms__7Server__x86_64
        rhel-7-server-supplementary-source-rpms__7Server__x86_64
      ]],

      ['7Workstation-7.0.Z-Workstation', %w[
        rhel-7-workstation-supplementary-debuginfo__7Workstation__x86_64
        rhel-7-workstation-supplementary-rpms__7Workstation__x86_64
        rhel-7-workstation-supplementary-source-rpms__7Workstation__x86_64
      ]],

    ])
  end

  # See https://engineering.redhat.com/rt/Ticket/Display.html?id=297123
  desc "Add missing rhel-7.0.z cdn repo link for 7Server-SAP-7.0.Z"
  task :for_7server_sap_7_0_z => :environment do
    do_create_cdn_repo_links([

      ['7Server-SAP-7.0.z', %w[
        rhel-sap-for-rhel-7-server-rpms__7Server__x86_64
        rhel-sap-for-rhel-7-server-debug-rpms__7Server__x86_64
        rhel-sap-for-rhel-7-server-source-rpms__7Server__x86_64
      ]],

    ])
  end

  # See https://engineering.redhat.com/rt/Ticket/Display.html?id=293205
  desc "Add rhel-7.0.z cdn repo links as requested by dgregor"
  task :for_rhel_7_0_z => :environment do

    do_create_cdn_repo_links([

      ['7Server-7.0.Z', %w[
        rhel-7-for-power-debug-rpms__7Server__ppc64
        rhel-7-for-power-rpms__7Server__ppc64
        rhel-7-for-power-source-rpms__7Server__ppc64
        rhel-7-for-system-z-debug-rpms__7Server__s390x
        rhel-7-for-system-z-rpms__7Server__s390x
        rhel-7-for-system-z-source-rpms__7Server__s390x
        rhel-7-server-debug-rpms__7Server__x86_64
        rhel-7-server-rpms__7Server__x86_64
        rhel-7-server-source-rpms__7Server__x86_64
      ]],

      ['7Client-7.0.Z', %w[
        rhel-7-desktop-debug-rpms__7Client__x86_64
        rhel-7-desktop-rpms__7Client__x86_64
        rhel-7-desktop-source-rpms__7Client__x86_64
      ]],

      ['7ComputeNode-7.0.Z', %w[
        rhel-7-hpc-node-debug-rpms__7ComputeNode__x86_64
        rhel-7-hpc-node-rpms__7ComputeNode__x86_64
        rhel-7-hpc-node-source-rpms__7ComputeNode__x86_64
      ]],

      ['7Workstation-7.0.Z', %w[
        rhel-7-workstation-debug-rpms__7Workstation__x86_64
        rhel-7-workstation-rpms__7Workstation__x86_64
        rhel-7-workstation-source-rpms__7Workstation__x86_64
      ]],

      ['7Server-optional-7.0.Z', %w[
        rhel-7-for-power-optional-debug-rpms__7Server__ppc64
        rhel-7-for-power-optional-rpms__7Server__ppc64
        rhel-7-for-power-optional-source-rpms__7Server__ppc64
        rhel-7-for-system-z-optional-debug-rpms__7Server__s390x
        rhel-7-for-system-z-optional-rpms__7Server__s390x
        rhel-7-for-system-z-optional-source-rpms__7Server__s390x
        rhel-7-server-optional-debug-rpms__7Server__x86_64
        rhel-7-server-optional-rpms__7Server__x86_64
        rhel-7-server-optional-source-rpms__7Server__x86_64
      ]],

      ['7Server-HighAvailability-7.0.Z', %w[
        rhel-ha-for-rhel-7-server-debug-rpms__7Server__x86_64
        rhel-ha-for-rhel-7-server-rpms__7Server__x86_64
        rhel-ha-for-rhel-7-server-source-rpms__7Server__x86_64
      ]],

      ['7Server-ResilientStorage-7.0.Z', %w[
        rhel-rs-for-rhel-7-server-debug-rpms__7Server__x86_64
        rhel-rs-for-rhel-7-server-rpms__7Server__x86_64
        rhel-rs-for-rhel-7-server-source-rpms__7Server__x86_64
      ]],

      ['7Client-optional-7.0.Z', %w[
        rhel-7-desktop-optional-debug-rpms__7Client__x86_64
        rhel-7-desktop-optional-rpms__7Client__x86_64
        rhel-7-desktop-optional-source-rpms__7Client__x86_64
      ]],

      ['7ComputeNode-optional-7.0.Z', %w[
        rhel-7-hpc-node-optional-debug-rpms__7ComputeNode__x86_64
        rhel-7-hpc-node-optional-rpms__7ComputeNode__x86_64
        rhel-7-hpc-node-optional-source-rpms__7ComputeNode__x86_64
      ]],

      ['7Workstation-optional-7.0.Z', %w[
        rhel-7-workstation-optional-debug-rpms__7Workstation__x86_64
        rhel-7-workstation-optional-rpms__7Workstation__x86_64
        rhel-7-workstation-optional-source-rpms__7Workstation__x86_64
      ]]

    ])

  end

  def do_create_cdn_repo_links(repos_by_variant)
    dry_run = ENV['REALLY'] != 'YES'

    repos_by_variant.each do |variant_name, cdn_repo_names|
      variant = Variant.find_by_name(variant_name)

      if !variant
        puts "** Skipping #{variant_name} because can't find variant!"
        next
      end

      cdn_repo_names.each do |cdn_repo_name|
        cdn_repo = CdnRepo.find_by_name(cdn_repo_name)

        if !cdn_repo
          puts "** Skipping #{cdn_repo_name} because can't find cdn repo!"
          next
        end

        if CdnRepoLink.exists?(:cdn_repo_id => cdn_repo, :variant_id => variant, :product_version_id => variant.product_version)
          puts "** Skipping #{cdn_repo_name} because link already exists!"
          next
        end

        # Now do it..
        link = CdnRepoLink.create!(:cdn_repo => cdn_repo, :variant => variant, :product_version => variant.product_version) unless dry_run

        puts "Link #{dry_run ? 'would be' : link.id} created for #{variant.product_version.name} - #{variant_name} - #{cdn_repo_name}"
      end

    end

    puts "Dry run mode. Add REALLY=YES to do it for real!" if dry_run
  end

end
