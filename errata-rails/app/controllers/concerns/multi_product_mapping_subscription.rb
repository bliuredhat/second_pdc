module MultiProductMappingSubscription
  extend ActiveSupport::Concern
  include ReplaceHtml

  def add_subscription
    name = params[:subscriber][:name].strip
    if name.present?
      subscriber = User.find_by_name(name)
    end
    if name.blank? || @multi_product_mapping.subscribers.include?(subscriber)
      render :text => ''
      return
    end

    @multi_product_mapping.subscribers << subscriber
    render_subscription_html
  end

  def remove_subscription
    subscription = if @multi_product_mapping.mapping_type == :channel
                     MultiProductChannelMapSubscription.find(params[:subscription_id])
                   else
                     MultiProductCdnRepoMapSubscription.find(params[:subscription_id])
                   end
    subscription.delete
    render_subscription_html
  end

  def render_subscription_html
    js = js_for_template(:subscription, 'subscription')
    render_js js
  end
end
