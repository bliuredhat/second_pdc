require 'active_support/concern'

module SharedApi::SearchByNameLike
  extend ActiveSupport::Concern

  private

  # This method helps composing LIKE query based on passed arguments and returns
  # the output in json format.
  # This uses params[:name] as keyword and where, map field are required to
  # fetch the proper output
  # e.g
  # _search_by_name_like(
  #    :where => 'channels.name like ? and errata_products.short_name not in ("RHEL", "LACD")',
  #    :limit => 50,
  #    :order => 'channels.name',
  #    :includes => { :product_version => :product },
  #    :select => lambda {|c| c.product_version.send("active_channels").include?(c)},
  #    :map => lambda {|c| {'name' => c.name, 'product' => c.product_version.product.short_name}}
  #  )
  def _search_by_name_like(args = {})
    list = []
    if params[:name].present?
      query = controller_name.classify.constantize
      query = query.joins(args[:joins]) if args[:joins]
      query = query.includes(args[:includes]) if args[:includes]
      query = query.where(args[:where], "%#{params[:name]}%").limit(args[:limit]||=50)
      query = query.order(args[:order]) if args[:order]
      query = query.select(&args[:select]) if args[:select]
      list = query.map(&args[:map])
    end
    respond_to do |format|
      format.json { render :json => list.to_json }
    end
  end
end
