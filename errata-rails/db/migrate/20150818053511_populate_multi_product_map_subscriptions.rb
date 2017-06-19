class PopulateMultiProductMapSubscriptions < ActiveRecord::Migration
  def up
    count = 0
    DATA.each do |package_name, dist_name, user_name|
      count += add_subscriptions(package_name, dist_name, user_name).count
    end
    puts "Added #{count} multi-product map subscriptions."
  end

  def add_subscriptions(package_name, dist_name, user_name)
    user = User.find_by_login_name("#{user_name}@redhat.com")
    unless user
      puts "No user #{user_name} - ignoring."
      return []
    end

    maps = [
      MultiProductChannelMap.joins(:destination_channel) .where(:channels =>  {:name => dist_name}),
      MultiProductCdnRepoMap.joins(:destination_cdn_repo).where(:cdn_repos => {:name => dist_name}),
    ].
      map{ |rel| rel.joins(:package).where(:packages => {:name => package_name}) }.
      map(&:to_a).
      inject(&:+)

    if maps.empty?
      puts "No matching multi-product maps for #{package_name}, #{dist_name}.  Ignoring."
    else
      maps.each do |m|
        m.subscribers << user
      end
    end

    maps
  end

  def down
    # Intentionally do nothing.
    # If you want to undo the addition of the data, just roll back one more
    # to drop the tables.
  end

  DATA = [
    # https://engineering.redhat.com/rt/Ticket/Display.html?id=363553
    ['libvirt', 'rhel-x86_64-server-6-rhs-3',          'sgirijan'],
    ['augeas',  'rhel-x86_64-server-6-rhs-3',          'sgirijan'],
    ['libvirt', 'rhel-x86_64-server-7-rh-gluster-3',   'sgirijan'],
    ['augeas',  'rhel-x86_64-server-7-rh-gluster-3',   'sgirijan'],
    ['rrdtool', 'rhel-x86_64-server-7-rh-gluster-3',   'sgirijan'],
    ['libvirt', 'rhs-3-for-rhel-6-server-rpms',        'sgirijan'],
    ['augeas',  'rhs-3-for-rhel-6-server-rpms',        'sgirijan'],
    ['libvirt', 'rh-gluster-3-for-rhel-7-server-rpms', 'sgirijan'],
    ['augeas',  'rh-gluster-3-for-rhel-7-server-rpms', 'sgirijan'],
    ['rrdtool', 'rh-gluster-3-for-rhel-7-server-rpms', 'sgirijan'],

    # https://engineering.redhat.com/rt/Ticket/Display.html?id=347118
    ['php', 'rhel-x86_64-server-6-ose-2.2-node', 'breilly'],
    ['php', 'rhel-x86_64-server-6-ose-2.1-node', 'breilly'],
    ['php', 'rhel-x86_64-server-6-ose-2.0-node', 'breilly'],

    # https://engineering.redhat.com/rt/Ticket/Display.html?id=341555
    ['vhostmd', 'rhel-x86_64-rhev-agent-6-server',    'jboggs'],
    ['vhostmd', 'rhel-x86_64-rhev-mgmt-agent-7-rpms', 'jboggs'],

    # https://engineering.redhat.com/rt/Ticket/Display.html?id=335365
    ['augeas',  'rhel-x86_64-rhev-agent-6-server',    'jboggs'],
    ['sanlock', 'rhel-x86_64-rhev-agent-6-server',    'jboggs'],
    ['augeas',  'rhel-x86_64-server-6-rhevm-3.4',     'jboggs'],
    ['sanlock', 'rhel-x86_64-server-6-rhevm-3.4',     'jboggs'],
    ['augeas',  'rhel-x86_64-server-6-rhevm-3.5',     'jboggs'],
    ['sanlock', 'rhel-x86_64-server-6-rhevm-3.5',     'jboggs'],
    ['augeas',  'rhel-x86_64-rhev-mgmt-agent-7-rpms', 'jboggs'],
    ['sanlock', 'rhel-x86_64-rhev-mgmt-agent-7-rpms', 'jboggs'],

    # https://engineering.redhat.com/rt/Ticket/Display.html?id=328921
    ['jasper', 'rhel-x86_64-server-6-ose-2.2-node', 'breilly'],
    ['jasper', 'rhel-x86_64-server-6-ose-2.1-node', 'breilly'],
    ['jasper', 'rhel-x86_64-server-6-ose-2.0-node', 'breilly'],
  ]
end
