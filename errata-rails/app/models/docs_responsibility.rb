class DocsResponsibility < ErrataResponsibility
  include Responsible

  #
  # Used to decide which tabs to show in docs queue. (Don't want to show the ones
  # that have nothing in them). See DocsController#get_secondary_nav.
  #
  def self.with_errata_in_docs_queue
    DocsResponsibility.find(Errata.in_docs_queue.select(:docs_responsibility_id).map(&:docs_responsibility_id).uniq, :order=>:name)
  end

end
