require 'gen_rss'
class RssObserver < ActiveRecord::Observer
  # (See commentary in errata_audit_observer)
  observe Errata, RHBA, RHSA, RHEA, Comment

  def after_create(obj)
    case obj
    when Errata
      ErrataRss.send_later :gen_rss, obj.id
      ErrataRss.send_later :write_opml, obj.release.id
    when Comment
      ErrataRss.send_later :gen_rss, obj.errata_id
    end
  end

  def after_update(obj)
    return unless obj.is_a?(Errata) && obj.group_id_changed?
    ErrataRss.send_later :write_opml, obj.release.id
    oldid = obj.changed_attributes['group_id']
    ErrataRss.send_later :write_opml, oldid
  end
end
