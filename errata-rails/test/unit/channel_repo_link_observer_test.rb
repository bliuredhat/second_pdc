require 'test_helper'

class ChannelRepoLinkObserverTest < ActiveSupport::TestCase

  test 'moving repo between variants updates the associated link' do
    update_variant_test(
      CdnRepo.find(1334),
      Variant.find_by_name!('6Server-RHEV-Virt-Agent'),
      Variant.find_by_name!('6Client-RHEV-Virt-Agent'))
  end

  test 'moving channel between variants updates the associated link' do
    update_variant_test(
      Channel.find(1349),
      Variant.find_by_name!('7Server-optional-LE-7.1.Z'),
      Variant.find_by_name!('7Server-LE-7.1.Z'))
  end

  test 'does nothing if old link is missing' do
    ch = Channel.find(54)
    old_variant = ch.variant
    new_variant = Variant.find_by_name!('6Server-LoadBalancer-6.2.z')
    refute old_variant == new_variant, 'fixture problem'
    assert ch.links.empty?, 'fixture problem'

    Rails.stubs(:logger => MockLogger)

    ch.variant = new_variant
    # should not create any link
    assert_difference('ChannelLink.count', 0) do
      ch.save!
    end

    # should warn about it
    assert_equal 'Found 0 link(s) for old variant - not updating', MockLogger.log.last
  end

  test 'does not crash on save failure' do
    ch = Channel.find(1349)
    new_variant = Variant.find_by_name!('7Server-LE-7.1.Z')

    # This will make the link update fail because the destination link
    # already exists.  (In normal circumstances, prevented by a
    # validation.)
    ChannelLink.new(
      :channel => ch,
      :variant => new_variant).save!(:validate => false)

    old_links = ch.links.order('id asc').map(&:attributes)

    Rails.stubs(:logger => MockLogger)

    ch.variant = new_variant

    # no new, deleted or modified links
    assert_difference('ChannelLink.count', 0) do
      ch.save!
    end

    new_links = ch.reload.links.order('id asc').map(&:attributes)
    assert_equal old_links, new_links

    # Should have logged something about it
    expected_log = 'Could not update variant on ChannelLink 2343 from 1038 to 1037:' \
                   ' Rhn channel has already been attached to this product version.'
    assert_equal expected_log, MockLogger.log.last
  end

  def update_variant_test(rec, old_variant, new_variant)
    link_with_old_variant = rec.links.where(:variant_id => old_variant)
    link_with_new_variant = rec.links.where(:variant_id => new_variant)

    assert_equal old_variant, rec.variant, 'fixture problem'
    assert link_with_old_variant.exists?

    old_link = link_with_old_variant.first
    updated_at = old_link.updated_at

    # If we change the variant for this channel/repo, the
    # corresponding link should be updated as well.
    rec.variant = new_variant
    rec.save!

    refute link_with_old_variant.reload.exists?
    assert link_with_new_variant.reload.exists?

    new_link = link_with_new_variant.first
    assert_equal old_link.id, new_link.id

    # ensure timestamp is updated too
    assert_not_equal updated_at, new_link.updated_at
  end
end
