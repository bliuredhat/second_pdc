class InfoRequestController < ApplicationController
  before_filter :find_errata

  def request_info
    set_page_title "Info Request for Advisory #{@errata.advisory_name}"
    return unless request.post?
    req = InfoRequest.create(:errata => @errata,
                             :summary => params[:summary],
                             :description => params[:description],
                             :info_role => Role.find_by_name(params[:role]))
    @errata.comments.create(:who => current_user,
                            :text => "Information requested from #{params[:role]}\n#{params[:summary]}\n#{params[:description]}",
                            :info_request=> req)
    redirect_to :action => :view, :controller => :errata, :id => @errata
  end

  def clear_info_request
    unless @errata.active_info_request
      flash_message :alert, "There is no active info request"
      redirect_to :action => :view, :id => @errata
      return
    end
    set_page_title "Clear Info Request for Advisory #{@errata.advisory_name}"
    return unless request.post?

    issue = @errata.active_info_request
    issue.is_active = false
    issue.save!
    @errata.comments.create(:who => current_user,
                            :text => "Info Request cleared: #{params[:description]}")
    redirect_to :action => :view, :controller => :errata, :id => @errata
  end
end
