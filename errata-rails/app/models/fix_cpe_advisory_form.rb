class FixCPEAdvisoryForm < FixAdvisoryForm
  include FormObject

  validate :is_textonly

  def apply_changes
    newcpe = params[:errata][:cpe_text]
    oldcpe = @errata.content.text_only_cpe
    @errata.content.text_only_cpe = newcpe
    @changemsg = "CPE text changed from: #{oldcpe} to #{@errata.content.text_only_cpe}"
  end

  def persist!
    begin
      @errata.content.save!
    rescue Exception => e
      errors.add(:errata, "Error occurred setting advisory CPE: #{e.to_s}")
      return false
    end

    # Push OVAL and XML to secalert
    return false unless push_to_secalert

    @errata.comments.create(:text => @changemsg)
  end

  private

  def is_textonly
    # (See also Errata#can_have_text_only_cpe?. Won't use it here even though it would work
    # similarly. Note that FixAdvisoryForm already requires that the advisory is shipped.)
    unless @errata.text_only?
      errors.add(:errata, "#{@errata.fulladvisory} is not a text only advisory.")
    end
  end
end
