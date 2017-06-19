
module NotifierHelper
  #
  # Have to set ActionMailer::Base.default_url_options for url_for to work here
  # since from action mailer we don't know the host or port... See environment.rb
  #
  def errata_text_url(errata)
    url_for :controller => 'errata', :action => 'view', :id => errata.id, :only_path => false
  end

  #
  # Same thing but for use in docs_update_reviewer email
  #
  def errata_text_docs_url(errata)
    url_for :controller => 'docs', :action => 'show', :id => errata.id, :only_path => false
  end

  #
  # Do not reply message that gets added to all emails
  #
  def please_do_not_reply_message(errata_specific=false)
    "(Please don't reply directly to this email#{". Any additional comments should be
made in ET via the 'Add Comment' form for this advisory" if errata_specific})."
  end

end
