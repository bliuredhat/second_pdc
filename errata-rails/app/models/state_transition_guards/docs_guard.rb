class DocsGuard < StateTransitionGuard
  def transition_ok?(errata)
    errata.docs_approved?
  end

  def ok_message(errata=nil)
    if errata
      "Docs #{errata.docs_status_text}"
    else
      "Docs approved"
    end
  end

  def failure_message(errata=nil)
    if errata
      "Docs #{errata.docs_status_text}"
    else
      "Docs not yet approved"
    end
  end

end
