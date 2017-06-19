module CheckList
  # A halper for checklist checks which include advisory links in their messages.
  module AdvisoryLinkHelper
    extend ActiveSupport::Concern
    include ActionView::Helpers::UrlHelper

    def advisory_link(advisory)
      # Not sure how to prevent `error_messages_for` from escaping the
      # html so only put links in if we specify :enable_links=>true
      return advisory.advisory_name unless @enable_links
      link_to(advisory.advisory_name, "/advisory/#{advisory.id}", :target=>'_blank')
    end
  end
end
