module DistRepo
  extend ActiveSupport::Concern

  included do
    around_filter :with_validation_error_rendering
    before_filter :admin_restricted
    before_filter :find_parent, :except => [:search_by_name_like]
    before_filter :find_variant, :only => [
      :create,
      :update,
      :attach_form,
      :attach,
      :link]
    before_filter :find_dist_repo, :only => [
      :show,
      :edit,
      :link,
      :unlink,
      :attach,
      :detach,
      :destroy]
  end

  def index
    (@inactive_repos, @active_repos) = @parent.
      send(controller_name).
      includes(dist_repo_links, :product_version, :arch).
      partition{|dist_repo| dist_repo.links.empty?}

    @linked_repos = @parent.
      send(dist_repo_links).
      includes(dist_repo_text).
      each_with_object({}) {|l,h| h[l.dist] = l}

    @all_repos = (@linked_repos.keys + @active_repos + @inactive_repos).uniq.sort_by(&:name)
    @indirect_repos = @all_repos - @active_repos - @inactive_repos
  end

  def attach_form
    @dist_repo = dist_repo_class.new(:variant => @variant)
    render "shared/variants/attach_form"
  end

  def show
    respond_with(self.instance_variable_get("@#{dist_repo_text}"))
  end

  def new
    dist_repo = dist_repo_class.new
    begin
      dist_repo.variant = find_variant
    rescue ActiveRecord::RecordNotFound => error
      # Do nothing if no variant is provided. Supporting 2 paths
      # 1) /product_versions/id/channels/new - won't preset variant
      # 2) /variants/id/channels/new - will preset variant
    end
    self.instance_variable_set(:"@#{dist_repo_text}", dist_repo)
    respond_to { |format| format.js {} } if request.xhr?
  end

  def create
    name = params[:"#{dist_repo_text}"][:name].strip
    # No longer support link and create in the same form
    if request.format != :html && dist_repo = dist_repo_class.find_by_name(name)
      self.instance_variable_set(:"@#{dist_repo_text}", dist_repo)
      # If it exists already then link it instead of creating a new one.
      attach
      return
    end
     # Create it
    self.send("create_or_update_#{dist_repo_text}")
  end

  def edit
  end

  # alias for attach
  def link
    attach
  end

  # alias for detach
  def unlink
    detach
  end

  def attach
    self.send("attach_#{dist_repo_text}_to_variant")
  end

  def detach
    self.send("detach_#{dist_repo_text}")
  end

  def update
    self.send("create_or_update_#{dist_repo_text}")
  end

  def destroy
    dist_repo = self.instance_variable_get("@#{dist_repo_text}")
    self.send("delete_#{dist_repo_text}")
  end

  def search_by_keyword
    table = controller_name
    fields = ["#{table}.id", "#{table}.name"]
    # only search for repos with the same product version family, such as
    # RHEl-6, RHEL-6.5.z, RHEL-6.6.z etc
    main_stream = @product_version.main_stream_product_version!

    respond_to do |format|
      list = []
      if name = params[:name]
        list = dist_repo_class.
          joins(:product_version => [:rhel_release]).
          select(fields.join(",")).
          where("#{table}.name like ? and errata_versions.product_id = ? and rhel_releases.name like ?",
            "%#{name}%", @product_version.product_id, "#{main_stream.name}%").
          map(&:attributes)
      end
      format.json { render :json => list.to_json}
    end
  end

  def search_by_name_like
    _search_by_name_like(
      :joins => "#{controller_name.singularize}_links".to_sym,
      :where => "#{controller_name}.name like ? and errata_versions.enabled = 1",
      :limit => 30,
      :order => "#{controller_name}.name",
      :includes => :product_version,
      :map => lambda {|c| { 'name' => c.name,
                            'product' => c.product_version.name }}
    )
  end

  protected

  def create_or_update_dist_repo(parent, opts = {})
    field = parent.class.name.underscore
    if action_name == 'create'
      opts[:options] = { field.to_sym => parent }
    end

    create_or_update(opts) do |dist_repo|
      message = "#{dist_repo.class.display_name} '#{dist_repo.name}' was successfully #{action_name}d."
      to_url = self.send("#{field}_#{dist_repo_text}_url", parent, dist_repo)
      redirect_to(to_url, :notice => message)
    end
  end

  def detach_dist_repo(dist_repo, source)
    dist_repos = Array.wrap(dist_repo)
    display_name = dist_repo_class.display_name
    source_humanize = source.class.name.underscore.humanize.downcase

    to_detach = source.
      send(dist_repo_links).
      select("#{dist_repo_links}.id").
      where("#{dist_repo_text}_id in (?)", dist_repos)

    if to_detach.empty?
      message = "The selected #{display_name.pluralize} don't attach to #{source_humanize} '#{source.name}'."
      raise ActiveRecord::RecordNotFound.new(message)
    end

    if to_detach.size > 1
      message = "#{to_detach.size} #{display_name.pluralize} have been detached"
    else
      message = "#{display_name} '#{dist_repos.first.name}' has been detached"
    end
    message += " with #{source_humanize} '#{source.name}' successfully."

    dist_repo_links.
      classify.
      constantize.
      where(:id => to_detach.map(&:id)).
      delete_all

    respond_with_success(message, :location => referrer_with_tab_path)
  end

  def attach_dist_repo_to_variant(dist_repo, variant = nil)
    variant = variant.present? ? variant : dist_repo.variant
    new_attach = dist_repo_links.
      classify.
      constantize.
      create!(dist_repo_text => dist_repo, :variant => variant)
    message =
      "#{dist_repo_class.display_name} '#{dist_repo.name}' has been attached" +
      " to variant '#{variant.name}' successfully."
    respond_with_success(message, :location => referrer_with_tab_path, :status => :created)
  end

  def delete_dist_repo(dist_repo)
    display_name = dist_repo_class.display_name
    unless dist_repo.destroy
      raise ActiveRecord::RecordInvalid.new(dist_repo)
    end
    message = "#{display_name} '#{dist_repo.name}' has been deleted successfully."
    respond_with_success(message, :location => referrer_with_tab_path)
  end

  private

  def referrer_with_tab_path
    back_to = params[:back_to_tab] ? params[:back_to_tab] : controller_name
    [referrer, "#{back_to}_tab"].join('#')
  end

  def find_parent
    #
    # cdn_repos is nested inside product version and variant.
    # The below routes are possible:
    # - /variants/:id/cdn_repos
    #   (param[variant_id] should be available)
    #
    # - /product_versions/:id/cdn_repos
    #   (param[product_version_id] should be available)
    #
    # - /product_versions/:id/variants/:id/cdn_repos
    #   (both params should be available and params[variant_id] precedes)
    #
    if params[:variant_id]
      @parent = find_variant
    elsif pv_id = params[:product_version_id]
      @parent = ProductVersion.find_by_id(pv_id)
      @product_version = @parent
    else
      # It looks like this code will never be triggered as long as we are not
      # adding a new route like '/cdn_repos/:id'
      raise ArgumentError.new("Product version or Variant not provided.")
    end
    return @parent
  end

  def find_variant
    unless @variant
      variant_id = params[:variant_id] ? params[:variant_id] :
        params[:"#{dist_repo_text}"] ? params[:"#{dist_repo_text}"][:variant_id] : nil
      @variant = Variant.find_by_id_or_name(variant_id)
    end
    # Just for convenience in views
    @product_version = @variant.product_version if !@product_version
    return @variant
  end

  def find_dist_repo
    dist_repo_id = if params[:id]
      params[:id]
    elsif params[:"#{dist_repo_text}"] && !params[:"#{dist_repo_text}"][:id].blank?
      params[:"#{dist_repo_text}"][:id]
    else
      message = action_name =~ /^(detach|unlink)$/ ?
        "No #{dist_repo_class.display_name.pluralize} are selected to detach." :
        "Missing #{dist_repo_class.display_name} id or name."
      raise ActiveRecord::RecordNotFound.new(message)
    end

    dist_repo = dist_repo_class.find_by_id_or_name(dist_repo_id)
    self.instance_variable_set(:"@#{dist_repo_text}", dist_repo)
  end

  def dist_repo_class
    controller_name.classify.constantize
  end

  def dist_repo_text
    controller_name.singularize
  end

  def dist_repo_links
    "#{dist_repo_text}_links"
  end
end
