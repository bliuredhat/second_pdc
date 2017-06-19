#update backup_channels set name = 'rhel-x86_64-server-productivity-5-fast' where id = 1128;

#update backup_channels set name = 'rhel-i386-server-productivity-5-fast' where id = 1066;
# BackupChannel.delete [1281,1282,1283,1284,1293]
# BackupChannel.where('product_version_id = 181 and ctype = ?', 'PrimaryChannel').each {|c| c.update_attribute(:name, "#{c.name}.1.z")}
# BackupChannel.where('product_version_id = 181 and ctype = ?', 'EusChannel').each {|c| c.delete }
# BackupChannel.where('product_version_id = 150 and ctype = ?', 'EusChannel').each {|c| c.delete}
# BackupChannel.find([1564,1565,1566,1567]).each {|b| BackupChannel.create!(:name => "#{b.name}.2.z", :ctype => 'EusChannel', :variant => b.variant, :arch => b.arch, :product_version => b.product_version)}
# BackupChannel.delete [79,928, 103,819, 107,922]
# BackupChannel.delete [42, 57, 61, 38, 34, 50, 54, 130]
# BackupChannel.delete [41, 53, 49, 145, 142, 148, 70, 71, 75]
# BackupChannel.delete [72,76, 143,144,146,147,149,150,151,67]
# 1281,1282,1283,1284,1293
class ConvChan
  def initialize
    @seen = Set.new
  end
  def convert_all
    [:conv_rhel,
     :convert_rhel58z,
     :conv_rhel_extras, 
     :conv_dup_safe, 
     :conv_rhel4_rhntools, 
     :conv_rhel5_rhntools, 
     :conv_rhel6_rhntools, 
     :conv_rhel5_sjis, 
     :conv_rhel5_rhev ].each do |k|
      puts k.to_s.humanize
      self.send(k)
    end
    puts "Done converting"
  end

  def conv_rhel
    BackupChannel.find(1128).update_attribute(:name, 'rhel-x86_64-server-productivity-5-fast')
    BackupChannel.find(1066).update_attribute(:name, 'rhel-i386-server-productivity-5-fast')
    convert_rhel6
    convert_rhel5
    convert_rhel4
    convert_rhel2_and_3
  end

  def convert_rhel_6_extras
    make_eus_channels 'RHEL-6.0.Z-Supplementary'
    z61 = ProductVersion.find_by_name 'RHEL-6.1.Z-Supplementary'
    BackupChannel.where('product_version_id = ? and ctype != ?', z61, 'PrimaryChannel').each do |b|
      klass = Kernel.const_get(b.ctype)
      c = klass.create!(
                       :name => b.name,
                       :arch => b.arch,
                       :variant => b.variant,
                       :product_version => b.product_version,
                       :cdn_binary_repo => b.cdn_path
                       )
    end

    p_channels = make_channels('RHEL-6-Supplementary').select {|c| PrimaryChannel == c.class}
    z62 = ProductVersion.find_by_name 'RHEL-6.2.Z-Supplementary'
    r6v = z62.variants.each_with_object({}) {|v,h| h[v.name.gsub('-6.2.z','')] = v}
    p_channels.each do |c|
      ChannelLink.create!(:channel => c, :product_version => z62, :variant => r6v[c.variant.name])
    end
    BackupChannel.where('product_version_id = ? and ctype != ?', z62, 'PrimaryChannel').each do |b|
      klass = Kernel.const_get(b.ctype)
      c = klass.create!(
                        :name => b.name,
                        :arch => b.arch,
                        :variant => b.variant,
                        :product_version => b.product_version,
                        :cdn_binary_repo => b.cdn_path
                        )
    end
  end

  def convert_rhel_5_extras
    ['RHEL-5.2.Z-Supplementary', 'RHEL-5.3.Z-Supplementary','RHEL-5.4.Z-Supplementary'].each {|n| make_eus_channels(n)}
    make_channels('RHEL-5.3.LL-Supplementary', LongLifeChannel)
    make_channels_primary_to_eus 'RHEL-5.6.Z-Supplementary'
    p_channels = make_channels('RHEL-5-Supplementary').select {|c| PrimaryChannel == c.class}
    z57 = ProductVersion.find_by_name 'RHEL-5.7.Z-Supplementary'
    r5v = z57.variants.each_with_object({}) {|v,h| h[v.name.gsub('-5.7.Z','')] = v}
    p_channels.each do |c|
      ChannelLink.create!(:channel => c, :product_version => z57, :variant => r5v[c.variant.name])
    end
  end

  def conv_rhel_extras
    convert_rhel_6_extras
    convert_rhel_5_extras
    ['RHEL-3-Extras', 'RHEL-4-Extras'].each {|n| make_channels(n)}
  end

  def convert_rhel6
    p_channels = make_channels('RHEL-6').select {|c| PrimaryChannel == c.class}

    z62 = ProductVersion.find_by_name 'RHEL-6.2.Z'
    BackupChannel.where('product_version_id = ? and ctype != ?', z62, 'PrimaryChannel').each do |b|
      klass = Kernel.const_get(b.ctype)
      c = klass.create!(
                       :name => b.name,
                       :arch => b.arch,
                       :variant => b.variant,
                       :product_version => b.product_version,
                       :cdn_binary_repo => b.cdn_path
                       )
    end
    
    r6v = z62.variants.each_with_object({}) {|v,h| h[v.name.gsub('-6.2.z','')] = v}
    p_channels.each do |c|
      v = r6v[c.variant.name]
      unless v
        puts "No match for #{c.variant.name}"
        next
      end
      ChannelLink.create!(:channel => c, :product_version => z62, :variant => r6v[c.variant.name])
    end
    
    channel = Channel.find_by_name 'rhel-s390x-server-6.2.z'
    ChannelLink.where(:channel_id => channel).each {|l| l.delete}
    channel.update_attribute(:variant, Variant.find_by_name('6Server-6.2.z'))
    ChannelLink.create!(:channel => channel, :product_version => channel.product_version, :variant => channel.variant)

    ['RHEL-6.1-EUS', 'RHEL-6.0.Z'].each {|n| make_eus_channels(n)}
  end

  def convert_rhel5
    p_channels = make_channels('RHEL-5').select {|c| PrimaryChannel == c.class}
    
    z57 = ProductVersion.find_by_name('RHEL-5.7.Z')
    #ROO
    r6v = z57.variants.each_with_object({}) {|v,h| h[v.name.gsub('-5.7.Z','')] = v}
    p_channels.each do |c|
      next unless r6v[c.variant.name]
      ChannelLink.create!(:channel => c, :product_version => z57, :variant => r6v[c.variant.name])
    end

    make_channels_primary_to_eus 'RHEL-5.6-EUS'
    make_channels('RHEL-5.3.LL', LongLifeChannel)
    ['RHEL-5.2.Z', 'RHEL-5.3.Z', 'RHEL-5.4.Z'].each {|n| make_eus_channels(n)}
    convert_rhel58z
    convert_rhel61z
    convert_rhel56z
  end

  def convert_rhel58z
    p_channels =  ProductVersion.find_by_name('RHEL-5').channels.where(:type => PrimaryChannel)
    r8z = ProductVersion.find_by_name('RHEL-5.8.Z')
    vmap = r8z.variants.each_with_object({}) {|v,h| h[v.name.gsub('-5.8.Z','')] = v}
    p_channels.each do |c|
      next unless vmap[c.variant.name]
      ChannelLink.create!(:channel => c, :product_version => r8z, :variant => vmap[c.variant.name])
    end
  end
  
  def convert_rhel61z
    pv = ProductVersion.find 180
    pve = ProductVersion.find 196
    vmap = {}
    pv.variants.each do |v|
      name = v.name.gsub('6.1.z', '6.1.EUS')
      ev = pve.variants.where(:name => name).first
      next unless ev
      vmap[ev] = v
    end
    pve.channels.each do |c|
      next unless vmap[c.variant]
      ChannelLink.create!(:channel => c, 
                          :product_version => pv, 
                          :variant => vmap[c.variant])
    end
  end

  def convert_rhel56z
    pv = ProductVersion.find 165
    pve = ProductVersion.find 191
    vmap = {}
    pv.variants.each do |v|
      name = v.name.gsub('5.6.Z', '5.6.EUS')
      ev = pve.variants.where(:name => name).first
      next unless ev
      vmap[ev] = v
    end
    pve.channels.each do |c|
      next unless vmap[c.variant]
      ChannelLink.create!(:channel => c, 
                          :product_version => pv, 
                          :variant => vmap[c.variant])
    end
  end

  def convert_rhel4
    make_channels('RHEL-4')
    ['RHEL-4.5.Z', 'RHEL-4.7.Z'].each {|n| make_eus_channels(n)}
  end

  def convert_rhel2_and_3
    ['RHEL-2.1', 'RHEL-3', 'RHEL-3-ELS'].each {|n| make_channels(n)}
  end

  def conv_dup_safe
    safe = ProductVersion.where('enabled = 1 and product_id in (select id from errata_products where isactive = 1 and id not in(?))', [16,23, 60, 55, 61, 52])
    safe.each {|s| make_channels(s.name)}
    ProductVersion.find(153, 155, 184).each {|s| make_channels(s.name)}
  end

  def conv_rhel5_rhev
    pv = ProductVersion.find_by_name 'RHEL-5-RHEV'
    channels = make_channels(pv.name)
    pv2 = ProductVersion.find_by_name 'RHEL-5-RHEV-2'
    vmap = {"5Server-RHEV-Hypervisor" => Variant.find_by_name("5Server-RHEV-Hypervisor-2"), 
      "5Server-RHEV-Agents" => Variant.find_by_name("5Server-RHEV-Agent"), 
      "5Server-RHEV-H-DevelopmentKit" => Variant.find_by_name("5Server-RHEV-Hypervisor-DevKit-2"), 
      "5Server-RHEV-Virt2Virt" => Variant.find_by_name("5Server-RHEV-V2V")}
    pv2_names = BackupChannel.where(:product_version_id => pv2).map(&:name).to_set
    channels.each do |c|
      next unless pv2_names.include?(c.name)
      ChannelLink.create!(:channel => c, :product_version => pv2, :variant => vmap[c.variant.name])
    end
  end

  def conv_rhel5_sjis
    sjis = ProductVersion.find_by_name 'RHEL-5-SJIS'
    p_channels = make_channels(sjis.name)
    sjis_56z = ProductVersion.find_by_name 'RHEL-5.6.Z-SJIS'
    BackupChannel.where('product_version_id = ? and ctype != ?', sjis_56z, 'PrimaryChannel').each do |b|
      klass = Kernel.const_get(b.ctype)
      c = klass.create!(
                       :name => b.name,
                       :arch => b.arch,
                       :variant => b.variant,
                       :product_version => b.product_version,
                       :cdn_binary_repo => b.cdn_path
                       )
    end
    p_channels.each {|c| ChannelLink.create!(:channel => c, :product_version => sjis_56z, :variant => sjis_56z.variants.first)}
    make_channels('RHEL-5.3.Z-SJIS', EusChannel)
  end

  def conv_rhel4_rhntools
    make_channels('RHEL-4-RHNTOOLS')
  end

  def conv_rhel5_rhntools
    make_channels('RHEL-5-RHNTOOLS')
    make_channels('RHEL-5-RHNTOOLS-5.3.LL', LongLifeChannel)
    make_channels_primary_to_eus('RHEL-5-RHNTOOLS-5.6.Z')
  end
  
  def conv_rhel6_rhntools
    Channel.transaction do
      ['RHEL-6-RHNTOOLS-6.0.Z', 'RHEL-6-RHNTOOLS-6.1-EUS'].each {|n| make_channels_primary_to_eus(n)}
      pv = ProductVersion.find_by_name 'RHEL-6-RHNTOOLS'
      p_channels = []
      BackupChannel.where('product_version_id = ? and ctype != ?', pv, 'EusChannel').each do |b|
        p_channels << PrimaryChannel.create!(
                                           :name => b.name,
                                           :arch => b.arch,
                                           :variant => b.variant,
                                           :product_version => b.product_version,
                                           :cdn_binary_repo => b.cdn_path
                                           )
      end
      pv2 = ProductVersion.find_by_name 'RHEL-6-RHNTOOLS-6.2.Z'
      BackupChannel.where('product_version_id = ? and ctype != ?', pv2, 'PrimaryChannel').each do |b|
        klass = Kernel.const_get(b.ctype)
        klass.create!(
                      :name => b.name,
                      :arch => b.arch,
                      :variant => b.variant,
                      :product_version => b.product_version,
                      :cdn_binary_repo => b.cdn_path
                      )
      end
      v62 = Variant.find_by_name '6Server-RHNTools-6.2.Z'
      p_channels.select {|c| c.variant.name == '6Server-RHNTools'}.each do |c|
        ChannelLink.create!(:channel => c, :product_version => pv2, :variant => v62)
      end
    end
  end

  def make_channels(pv_name, create_class = nil)
    pv = ProductVersion.find_by_name pv_name
    channels = []
    BackupChannel.where('product_version_id = ?', pv).each do |b|
      klass = create_class
      klass ||= Kernel.const_get(b.ctype)
      puts "#{pv.id} #{pv.name} #{klass} #{b.name}"
      channels << klass.create!(
                                :name => b.name,
                                :arch => b.arch,
                                :variant => b.variant,
                                :product_version => b.product_version,
                                :cdn_binary_repo => b.cdn_path
                                )
    end
    channels
  end

  def make_eus_channels(pv_name)
    make_channels(pv_name, EusChannel)
  end


  def make_channels_primary_to_eus(pv_name)
    pv = ProductVersion.find_by_name pv_name
    BackupChannel.where('product_version_id = ?', pv).each do |b|
      klass = Kernel.const_get(b.ctype)
      klass = EusChannel if b.ctype == 'PrimaryChannel'
      c = klass.create!(
                          :name => b.name,
                          :arch => b.arch,
                          :variant => b.variant,
                          :product_version => b.product_version,
                          :cdn_binary_repo => b.cdn_path)
    end

  end
end

