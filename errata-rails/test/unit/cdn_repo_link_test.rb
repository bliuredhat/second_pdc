require 'test_helper'

class CdnRepoLinkTest < ActiveSupport::TestCase
  [:variant, :cdn_repo].each do |attr|
    attrs = {
      :variant => Variant.first,
      :cdn_repo => CdnRepo.first
    }
    attrs.delete(attr)

    test "can't create without #{attr}" do
      link = CdnRepoLink.create(attrs)
      refute link.valid?
      errors = link.errors.full_messages
      assert errors.include?("#{attr.to_s.humanize} can't be blank"), errors.join("\n")
    end
  end

  test "can't create duplicate repo link within a product version" do
    pv = ProductVersion.find_by_name!('RHEL-7.0.Z')
    repo = CdnRepo.find_by_name!('cdn-rhel6-repo-SRPMS')

    assert pv.variants.count > 1, 'test data problem: pv needs at least two variants'
    v = pv.variants.first

    attrs = {
      :cdn_repo => repo,
      :variant => v,
    }

    # first link can create ok...
    CdnRepoLink.create!(attrs)

    # ...but linking to another variant in the same pv is rejected
    link = CdnRepoLink.new(attrs.merge(:variant => pv.variants.second))
    refute link.valid?
    assert_equal ['Cdn repository has already been attached to this product version.'], link.errors.full_messages
  end
end
