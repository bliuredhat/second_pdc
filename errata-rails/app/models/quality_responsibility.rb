class QualityResponsibility < ErrataResponsibility
  include Responsible
  validate :owner_in_qa_role?
  
  private
  def owner_in_qa_role?
    unless default_owner.in_role?('qa')
      errors.add(:default_owner, "User #{default_owner.to_s} not in qa role!")
    end
  end
  
end
