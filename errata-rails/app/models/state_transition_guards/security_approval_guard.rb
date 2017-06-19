class SecurityApprovalGuard < StateTransitionGuard
  def transition_ok?(errata)
    !errata.requires_security_approval? || errata.security_approved?
  end

  def ok_message(errata=nil)
    if errata
      if errata.requires_security_approval?
        "Approved by Product Security"
      else
        "Product Security approval is not required"
      end
    else
      "Approved by Product Security (RHSA only)"
    end
  end

  def failure_message(errata=nil)
    "Advisory must have Product Security approval"
  end
end
