class FixAdvisoryForm
  include FormObject

  attr_accessor :errata, :params, :changemsg
  validate :advisory_shipped_live

  def initialize(errata, params={})
    self.errata = errata
    self.params = params
    @changemsg = ""
  end

  def new_record?
    true
  end

  def persisted?
    false
  end

  def push_to_secalert
    begin
      Push::Oval.push_oval_to_secalert(@errata)
    rescue StandardError => e
      errors.add(:errata, "Error occurred updating errata OVAL: #{e.to_s}")
      return false
    end

    begin
      Push::ErrataXmlJob.enqueue(@errata)
    rescue => e
      errors.add(:errata, "Error occurred pushing XML to secalert: #{e.to_s}")
      return false
    end

    return true
  end

  private

  def advisory_shipped_live
    unless @errata.status == State::SHIPPED_LIVE
      errors.add(:errata, "#{@errata.fulladvisory} has not been pushed to RHN Live yet.")
    end
  end

end
