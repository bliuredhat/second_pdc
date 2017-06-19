class SecurityController < ApplicationController
  include ReplaceHtml
  before_filter :security_restricted, :set_index_nav

  verify :method => :post, :only => [:regenerate_oval, :push_xml_to_secalert, :request_rcm_push]
  respond_to :html, :json

  def active
    @errata_list = Errata.find(:all,
                             :conditions => "is_valid = 1 and status not in ('SHIPPED_LIVE', 'DROPPED_NO_SHIP') and closed = 0 and errata_type in ('RHSA', 'PdcRHSA')",
                             :order => 'errata_main.fulladvisory ',
                             :include => [:reporter, :product, :content])

    set_page_title "Active Security Advisories"
    respond_with(@errata_list)
  end

  def cpe_for_channel
    chan = Channel.find_by_name(params[:id])
    return redirect_to_error!("No such rhn channel #{params[:id]}") unless chan

    v = chan.variant
    respond_to do |format|
      format.text { render :text => "#{v.cpe},#{v.name},#{v.description}"}
      format.json { render :json => { :cpe => v.cpe, :name => v.name, :description => v.description}.to_json }
    end
  end
  
  def update_variant_cpe
    @variant = Variant.find(params[:variant][:id])
    @variant.update_attributes(params[:variant])
    new_html = partial_to_string('security/cpe_management_inline_edit', {})
    if request.xhr?
      render_js js_for_html "edit_variant_cpe_#{@variant.id}", new_html, 'replaceWith'
    else
      redirect_to :action => :cpe_management
    end
  end

  def cpe_management
    extra_javascript %w[inline_editform cpe_management]
    @product_versions = ProductVersion.with_active_product.includes(:variants).all
    set_page_title 'CPE Management'
  end

  def find_rhsa_to_fix_cve
    find_rhsa_to_fix :fix_cve_names
  end

  def find_rhsa_to_fix_cpe
    find_rhsa_to_fix :fix_cpe
  end

  def find_rhsa_to_fix(redirect_to_action)
    advisory = params[:advisory][:name] if params[:advisory]
    unless advisory
      redirect_to_error!("Advisory cannot be blank in search")
      return
    end

    begin
      errata = Errata.find_by_advisory(advisory)
    rescue
      redirect_to_error!("Unable to find errata with id: " + advisory)
    else
      redirect_to :action => redirect_to_action, :id => errata
    end
  end

  def fix_cpe
    set_page_title "Errata Fixup - CPE"
    if params[:id] || params[:advisory]
      return unless find_errata
    else
      return
    end
    fix_advisory_helper FixCPEAdvisoryForm.new(@errata, params)
  end

  def fix_cve_names
    set_page_title "Errata Fixup - CVE name"
    if params[:id] || params[:advisory]
      return unless find_errata
    else
      return
    end

    fix_advisory_helper FixCVEAdvisoryForm.new(@errata, params)
  end

  def index
    redirect_to :action  => :active
  end

  def live_cpe
    variants = Variant.live_variants_with_cpe
    @unique_cpe = Hash.new { |hash, key| hash[key] = { }}
    variants.each do |v|
      next if @unique_cpe.has_key?(v.cpe)
      @unique_cpe[v.cpe][:name] = v.name
      @unique_cpe[v.cpe][:description] = v.description
    end

    respond_to do |format|
      format.html { set_page_title "Live CPE Info" }
      format.json { render :layout => false, :json => @unique_cpe.to_json }
    end
  end

  def regenerate_oval
    return unless find_errata
    respond = build_respond

    unless @errata.supports_oval?
      return respond.call("OVAL is not supported for this type of advisory", :error, :bad_request)
    end

    begin
      Push::Oval.push_oval_to_secalert(@errata)
    rescue => e
      return respond.call("Error re-pushing oval to secalert: #{e.to_s} - #{e.message}", :error, :internal_server_error)
    end
    respond.call('OVAL has been regenerated and pushed to secalert', :notice, :ok)
  end

  def push_xml_to_secalert
    return unless find_errata
    respond = build_respond

    begin
      Push::ErrataXmlJob.enqueue(@errata)
    rescue => e
      return respond.call("Error occurred pushing XML to secalert: #{e.to_s}", :error, :internal_server_error)
    end
    respond.call('Push XML job enqueued', :notice, :ok)
  end

  def request_rcm_push
    return unless find_errata
    respond = build_respond
    begin
      Notifier.request_rcm_rhsa_push(@errata).deliver
      comment = @errata.comments.create!(:who => current_user, :text => 'Product Security requested RCM push for this advisory.')
      @errata.request_rcm_push_comment_id = comment.id
      @errata.save!
    rescue => e
      return respond.call("Error occurred requesting RCM push: #{e.to_s}", :error, :internal_server_error)
    end
    respond.call("Requested RCM push for #{@errata.fulladvisory}", :notice, :ok)
  end

  private

  def build_respond
    lambda do |msg, target, status|
      respond_to do |format|
        format.html do
          flash_message target, msg
          redirect_to :controller => :errata, :action => :view, :id => @errata
        end
        format.any do
          if :ok == status
            render :nothing => true, :status => status
          else
            render :text => msg, :status => status
          end
        end
      end
    end
  end

  def get_secondary_nav
    nav = []
    nav << { :name => 'Active Security Errata', :controller => :security, :action => :active}
    nav << { :name => 'Fix CVE Names', :controller => :security, :action => :fix_cve_names}
    nav << { :name => 'Fix CPE', :controller => :security, :action => :fix_cpe}
    nav << { :name => 'CPE Management', :controller => :security, :action => :cpe_management}
    return nav
  end

  def fix_advisory_helper(form)
    unless form.valid?
      flash_message :error, form.errors.full_messages.join(' ')
      @errata = nil
      return
    end

    return unless request.post?
    form.apply_changes
    unless form.save
      full_error_text = form.errors.full_messages.join(' ')
      if full_error_text.length > 2000
        # Can get a full python stack trace from pub here which causes
        # ActionDispatch::Cookies::CookieOverflow errors if you put it in flash[:error]
        redirect_to_error!(full_error_text)
      else
        flash_message :error, full_error_text
      end
      return
    end
    flash_message :notice, form.changemsg

    # Let the UI show which pub targets couldn't be updated.
    # Fix cpe form doesn't need the pub_task_errors because it doesn't send any
    # request to pub.
    @pub_task_errors = form.pub_task_errors if form.respond_to?(:pub_task_errors)
  end

end
