# Observes changes to relevant CPE data, publishes cache if it is stale
class CpeObserver < ActiveRecord::Observer
  # (See commentary in errata_audit_observer)
  observe Errata, RHSA, RHEA, RHBA, Content, Variant

  def after_update(obj)
    return unless obj.public_cpe_data_changed?
    Secalert::CpeMapper.enqueue_once :publish_cache, Settings.secalert_cpe_starting_year
  end
end
