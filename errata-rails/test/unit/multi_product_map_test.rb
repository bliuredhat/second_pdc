require 'test_helper'

class MultiProductMapTest < ActiveSupport::TestCase
  test "get possibly_relevant_mappings_for_advisory" do
      errata = Errata.find(13147)
      relevant_mappings = MultiProductMap.possibly_relevant_mappings_for_advisory(errata).
        sort_by{|multi_product_map| multi_product_map.destination_dist.name}

      expected_multi_product_maps = [
        {:package => "sblim-cim-client2", :destination_dist => "rhel-6-rhev-s-rpms__6Server-RHEV-S__x86_64"},
        {:package => "sblim-cim-client2", :destination_dist => "rhel-x86_64-server-6-rhevh"},
      ]
      assert_equal expected_multi_product_maps.size, relevant_mappings.size
      expected_multi_product_maps.each_with_index do |expected, idx|
        [:package, :destination_dist].each do |field|
          assert_equal expected[field], relevant_mappings[idx].send(field).name
        end
      end
  end
end
