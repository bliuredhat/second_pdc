class SigningController < ApplicationController
  before_filter :find_errata,
  :except => [:list]
  before_filter :signer_restricted, :only => [:mark_as_signed, :remove_needsign_flag, :revoke_signatures]
  verify :method => :post, :except => [:list, :index, :unsigned_builds]

  def list
    @tosign = Errata.find(:all, :conditions => 'sign_requested = 1')
    respond_to do |format|
      format.html
      format.text { render :text => @tosign.collect { |e| e.id }.join(',')}
      format.json { render :json => @tosign.collect { |e| e.id }.to_json }
    end
  end

  def request_signatures
    msg = "Signatures have been requested."
    user = current_user
    begin
      Notifier.errata_request_signatures(@errata).deliver
      @errata.update_attribute(:sign_requested, true)
      @errata.comments << SignaturesRequestedComment.new(:who => User.default_qa_user, :text => "#{user.realname} (#{user.login_name}): #{msg}")
      flash_message :notice, msg
    rescue Net::SMTPError => e
      logger.error "SMTP Error requesting signatures #{e.class} #{e.message}"
      flash_message :error, "An SMTP error occurred requesting signatures. Please try again in a few minutes"
    end
    redirect_to :action => :view, :controller => :errata, :id => @errata
  end

  def revoke_signatures
    @errata.brew_builds.each do |b|
      b.revoke_signatures!
    end

    @errata.current_files.each do |f|
      f.update_file_path
      f.save
    end

    @errata.sign_requested = 1
    @errata.save
    Notifier.errata_request_signatures(@errata).deliver
    msg = "Bad signature state has been removed, and new sigs requested."
    @errata.comments << SignaturesRevokedComment.new(:text => msg)

    respond_to do |format|
      format.html do
        flash_message :notice, msg
        redirect_to :action => :view, :controller => :errata, :id => @errata
      end
      format.any { render :text => 'ok', :status => 200 }
    end
  end

  def unsigned_builds
    no_key = SigKey.find_by_name 'none'
    unsigned_maps = @errata.build_mappings.for_rpms.where('brew_builds.sig_key_id = ?', no_key)
    @map = Hash.new { |hash, key| hash[key] = { }}

    unsigned_maps.each do |map|
      nvr = map.brew_build.nvr
      @map[nvr][:sig_key_id] =  map.product_version.sig_key.keyid
      @map[nvr][:sig_key_name] =  map.product_version.sig_key.sigserver_keyname
      @map[nvr][:rpms] = map.brew_build.brew_rpms.collect { |r| r.file_path }
    end
    set_page_title "Unsigned Builds for #{@errata.advisory_name} #{@errata.synopsis}"
    respond_to do |format|
      format.html
      format.xml
      format.json { render :json => @map.to_json }
      format.text do
        builds = []
        @map.keys.each do |nvr|
          text = [nvr,@map[nvr][:sig_key_id],@map[nvr][:sig_key_name]].concat(@map[nvr][:rpms]).join(',')
          builds << text
        end
        render :layout => false, :text => builds.join("\n")
      end
    end
  end

  def mark_as_signed
    begin
      build = BrewBuild.find_by_nvr(params[:brew_build])
      raise "No such build #{params[:brew_build]}" unless build
      map = @errata.build_mappings.for_rpms.where(['brew_build_id = ?', build]).first
      raise "No such mapping or no RPMs in mapping #{@errata.id} <=> #{build.nvr}" unless map
      key = SigKey.find_by_keyid params[:sig_key]
      raise "Key not found #{params[:sig_key]}" unless key
      unless map.product_version.sig_key == key
        raise "Invalid key for product: Expected #{map.product_version.sig_key.keyid}, got #{key.keyid}"
      end

      build.mark_as_signed(key)

      user = User.current_user
      @errata.comments << BuildSignedComment.new(:text => "Build #{build.nvr} signed with key #{key.keyid}", :who => user)
      @errata.activities.create(:what => 'signing', :who => user, :added => build.nvr)
      logger.info user.to_s + " signed build #{build.nvr} for errata #{@errata.id} with key #{key.keyid}"
    rescue => e
      redirect_to_error! e.message
      return
    end
    render :text => 'ok', :status => 200
  end

  def remove_needsign_flag
    @errata.sign_requested = 0
    @errata.save(:validate => false)
    render :text => 'ok', :status => 200
  end

  private
  def signer_restricted
    validate_user_roles('signer')
  end
end
