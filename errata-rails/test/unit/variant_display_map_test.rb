require 'test_helper'

class VariantDisplayMapTest < ActiveSupport::TestCase
  test 'can autovivify for write' do
    map =  VariantDisplayMap::ChannelsAndRepos.new
    variants = Variant.where(:name => ["6Server", "6Server-6.5.z"])

    variants.each do |v|
      channel_links = ChannelLink.where(:variant_id => v)
      cdn_repo_links = CdnRepoLink.where(:variant_id => v)

      [[channel_links, :channels], [cdn_repo_links, :cdn_repos]
      ].each do |links, method|
        links.each do |l|
          map.send(method) << l
        end
      end
    end

    expected = {
      :channels => [
        ["6Server",
          %w[rhel-i386-server-fastrack-6
             rhel-x86_64-server-fastrack-6
             rhel-s390x-server-fastrack-6
             rhel-ppc64-server-fastrack-6
             rhel-i386-server-6
             rhel-x86_64-server-6
             rhel-s390x-server-6
             rhel-ppc64-server-6
          ]],
        ["6Server-6.5.z",
          %w[rhel-x86_64-server-6.5.z
             rhel-x86_64-server-6.5.aus
             rhel-x86_64-server-6
          ]]
      ],
      :cdn_repos => [
        ["6Server",
          %w[rhel-6-server-debuginfo-rpms__6Server__i386
             rhel-6-server-rpms__6Server__i386
             rhel-6-server-debuginfo-rpms__6Server__x86_64
             rhel-6-server-rpms__6Server__x86_64
             rhel-6-server-source-rpms__6Server__x86_64
             test_rhel6_docker
             rhel-6-server-debuginfo-rpms__6Server__s390x
             rhel-6-server-rpms__6Server__s390x
             rhel-6-server-debuginfo-rpms__6Server__ppc64
             rhel-6-server-rpms__6Server__ppc64
          ]],
        ["6Server-6.5.z",
          %w[rhel-6-server-eus-debug-rpms__6_DOT_5__x86_64
             rhel-6-server-eus-rpms__6_DOT_5__x86_64
             rhel-6-server-eus-source-rpms__6_DOT_5__x86_64
             rhel-6-server-rpms__6Server__i386
             rhel-6-server-debuginfo-rpms__6Server__x86_64
             rhel-6-server-rpms__6Server__x86_64
             rhel-6-server-source-rpms__6Server__x86_64
             rhel-6-server-rpms__6Server__s390x
             rhel-6-server-rpms__6Server__ppc64
          ]]
      ]
    }

    assert_equal(expected, actual_data(map))
  end

  test "all repos for variant" do
    v = Variant.find_by_name!("6Server")
    map = VariantDisplayMap.for_variant(v)

    expected = {
      :channels => [
        ["6Server",
          %w[rhel-i386-server-fastrack-6
             rhel-x86_64-server-fastrack-6
             rhel-s390x-server-fastrack-6
             rhel-ppc64-server-fastrack-6
             rhel-i386-server-6
             rhel-x86_64-server-6
             rhel-s390x-server-6
             rhel-ppc64-server-6
          ]]
      ],
      :cdn_repos => [
        ["6Server",
          %w[rhel-6-server-debuginfo-rpms__6Server__i386
             rhel-6-server-rpms__6Server__i386
             rhel-6-server-debuginfo-rpms__6Server__x86_64
             rhel-6-server-rpms__6Server__x86_64
             rhel-6-server-source-rpms__6Server__x86_64
             test_rhel6_docker
             rhel-6-server-debuginfo-rpms__6Server__s390x
             rhel-6-server-rpms__6Server__s390x
             rhel-6-server-debuginfo-rpms__6Server__ppc64
             rhel-6-server-rpms__6Server__ppc64
          ]]
      ]
    }
    assert_equal(expected, actual_data(map))
  end

  # builds a somewhat realistic map and compares against an expected value.
  test 'compare against baseline' do
    # there's no existing testdata which has all of: linked channels, linked repos, owned channels, owned repos.
    # RHEL-7.0.Z is the closest, so pick that and modify it.
    pv = ProductVersion.find_by_name!('RHEL-7.0.Z')
    v = Variant.find_by_name!('7Client-7.0.Z')

    arch1 = Arch.find_by_name!('alpha')
    arch2 = Arch.find_by_name!('amd64')

    [PrimaryChannel,CdnBinaryRepo].each do |klass|
      [arch1, arch2].each_with_index do |arch, archidx|
        [1,2].each do |i|
          klass.create!({
            :name => "test-#{klass.name}-#{i}-#{archidx+1}",
            :arch => arch,
            :variant => v}.merge(
              klass == PrimaryChannel ? {:product_version => pv} : {}
            )
          )
        end
      end
    end

    map = VariantDisplayMap.for_product_version(pv)
    assert_testdata_equal 'variant_display_map_typical.json', canonicalize_json(actual_data(map).to_json)
  end

  def actual_data(map)
    [:channels, :cdn_repos].each_with_object(HashList.new) do |method,h|
      outputs = map.send(method).sort
      outputs.each do |(v,repos)|
        h[method] << [v.name, repos.map(&:name)]
      end
    end
  end
end
