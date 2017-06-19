class ChannelRepoLinkObserver < ActiveRecord::Observer
  observe Channel, CdnRepo

  def after_update(rec)
    return unless rec.variant_id_changed?

    (old_variant,new_variant) = [
      rec.changed_attributes['variant_id'],
      rec.variant]

    Rails.logger.info "Variant changed on #{rec.class} #{rec.id} from #{old_variant} to #{new_variant.id}"

    links = rec.links.where(:variant_id => old_variant).to_a
    if links.length != 1
      # This is an unusual situation
      Rails.logger.warn "Found #{links.length} link(s) for old variant - not updating"
      return
    end

    link = links.first
    link.variant = new_variant
    update_str = "variant on #{link.class} #{link.id} from #{old_variant} to #{new_variant.id}"
    if link.save
      Rails.logger.info "Updated #{update_str}"
    else
      # The reason this is logging instead of raising on error is
      # because situations may arise where invalid data has previously
      # been saved (e.g. multiple links within one product version),
      # and I don't think we should block updating the channel/repo in
      # that case.
      Rails.logger.error "Could not update #{update_str}: #{link.errors.full_messages.join('\n')}"
    end
  end
end
