module AdvisoryFinder
  extend ActiveSupport::Concern
  include ErrorHandling

  def find_errata
    id = nil

    # Although :advisory is more specific than :id, it comes last because
    # :advisory is also used to pass a hash to various actions.
    [:erratum_id, :id, :advisory].each do |key|
      break if id = params[key]
    end

    unless id
      return redirect_to_error!("No errata id given.")
    end

    begin
      @errata = Errata.find_by_advisory(id)
      if current_user && current_user.is_readonly?
        return permission_error!('readonly') if @errata.is_embargoed?
      end
    rescue => e
      return redirect_to_error!("Unable to find errata with id: #{id}: " + e.message)
    end
    return true
  end
end
