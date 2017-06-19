class BlockingIssueController < ApplicationController
  before_filter :find_errata

  def block_errata
    set_page_title "Block Advisory #{@errata.advisory_name}"
    return unless request.post?

    b = params[:blocking_issue]
    BlockingIssue.transaction do
      begin
        @blocking_issue = BlockingIssue.create!(:summary => b[:summary],
                                                :description => b[:description],
                                                :blocking_role => Role.find_by_name(b[:role_name]),
                                                :who => current_user,
                                                :errata => @errata)
        @errata.comments.create!(:who => current_user,
                                 :text => "Errata Blocked on #{@blocking_issue.blocking_role.name}\n#{@blocking_issue.summary}\n#{@blocking_issue.description}",
                                 :blocking_issue => @blocking_issue)
        respond_to do |format|
          format.html {redirect_to :action => :view, :controller => :errata, :id => @errata}
          format.any { head :ok }
        end
      rescue => e
        respond_to do |format|
          format.html { redirect_to_error!("Error creating blocking issue for advisory: #{e.message}") }
          format.json { render :json => {:errors => e.message}.to_json, :status => :unprocessable_entity  }
          format.any  { head  :unprocessable_entity  }
        end
      end
    end
  end

  def unblock_errata
    unless @errata.active_blocking_issue
      flash_message :alert, "There is no active blocking issue"
      redirect_to :action => :view, :id => @errata
      return
    end

    set_page_title "Unblock Advisory #{@errata.advisory_name}"
    return unless request.post?

    issue = @errata.active_blocking_issue
    issue.is_active = false
    issue.save!
     
    @errata.comments.create(:who => current_user,
                            :text => "Advisory Unblocked: #{params[:description]}")

    redirect_to :action => :view, :controller => :errata, :id => @errata
  end
end
