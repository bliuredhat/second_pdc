require 'test_helper'

class ArchTest < ActiveSupport::TestCase

  test 'basic creation' do
    a = Arch.new(:name => 'ppc64le')
    assert_valid a

    a = Arch.new(:name => 'amd',
                 :active => false)
    assert_valid a
  end

  test 'verify uniqueness constraints' do
    a = Arch.last
    dup = Arch.new(:name => a.name)
    assert_raise(ActiveRecord::RecordNotUnique) { dup.save() }
  end

  test 'validate active_machine_arches' do
    @active_arches = Arch.active_machine_arches

    Arch.where(:active => true) do |arches|
      assert_equal 7, arches.count, "(maybe fixture changed)"
      assert_array_equal @active_arches, arches
    end
  end

end
