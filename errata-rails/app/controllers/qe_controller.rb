class QeController < ApplicationController
  before_filter :set_index_nav
  verify :method => :post, :only => [:assign_errata_to_me],
         :redirect_to => { :action => :index }

  def assign_errata_to_me
    return unless find_errata
    user = current_user
    redirect_to :back

    unless @errata.unassigned?
      flash_message :alert,
        "#{@errata.advisory_name} - #{@errata.synopsis} has already been assigned to #{@errata.assigned_to.to_s}."
      return
    end
    if user.in_role?('qa')
      @errata.assigned_to = user
      @errata.save
      flash_message :notice, "#{@errata.advisory_name} - #{@errata.synopsis} has been assigned to me."
    else
      flash_message :error, "You are not in the QA Role and cannot be assigned errata"
    end
  end
  
  def index
    redirect_to :action => :errata_for_qe_group, 
    :id => QualityResponsibility.find(:first).url_name
  end
  
  def errata_for_qe_group
    unless params[:id]
      redirect_to :action => :errata_for_qe_group, 
      :id => QualityResponsibility.find(:first).url_name
      return
    end

    if params[:id].to_i > 0
      redirect_to :action => :errata_for_qe_group, :id => get_responsibility_from_id(params[:id].to_i).url_name
      return
    end

    resp = QualityResponsibility.find_by_url_name(params[:id])
    unless resp
      flash_message :error, "No such QE Group: #{params[:id]}"
      index
      return
    end
    @release_errata = HashList.new
    resp.errata.each { |e| @release_errata[e.release.name] << e }

    set_page_title "Active Advisories for #{resp.name}"
  end

  def my_requests
    @user = current_user
    @button_bar_partial = 'errata/new_advisory_button'
    set_page_title "Active Advisories Requests for #{@user.realname}"

    assigned_errata = []
    attention_states = Set.new

    if(@user.in_role?('qa'))
      assigned_errata = @user.assigned_errata.find(:all, 
                                                    :conditions => ['is_valid = 1 and status not in (?)',
                                                                    ['SHIPPED_LIVE', 'DROPPED_NO_SHIP']], 
                                                    :include => [:bugs])
      
      attention_states << State::QE



      
    elsif(@user.in_role?('devel'))
      assigned_errata = @user.devel_errata.active
      assigned_errata.concat(@user.reported_errata.active)

      attention_states << State::NEW_FILES
      #@actions = {State::NEW_FILES => [{:desc => 'Update Brew Builds', :action=> 'list_files', :controller=> 'brew'}]}

    end
    
    @filed_bugs = []
    @assigned_errata = assigned_errata.map do |e|
      @filed_bugs.concat(e.filed_bugs)
      [e, attention_states.include?(e.status), @user]
    end

  end

  def unassigned
    set_page_title "Unassigned Advisories"
    @unassigned = Errata.unassigned_errata
  end

  private
  
  def get_responsibility_from_id(id)
    if id >= 3000000
      old_qe_org = User.find(id)
      resp = QualityResponsibility.find(:first, :conditions => ['name = ?', old_qe_org.realname])
      resp = QualityResponsibility.find(:first) unless resp
    else
      resp = QualityResponsibility.find(id)
    end
    return resp
  end
  
  def get_secondary_nav
    nav = []
    nav << { :name => 'My Assigned Advisories',
    :controller => :qe,
    :action => :my_requests}
    
    nav << { :name => 'Unassigned Advisories',
    :controller => :qe,
    :action => :unassigned}
    
    QualityResponsibility.find(:all, :order => 'name').each do |org|
      nav << { :name => org.name,
      :controller => :qe,
        :action => :errata_for_qe_group,
        :id => org.url_name}
    end
    
    return nav
  end

end

