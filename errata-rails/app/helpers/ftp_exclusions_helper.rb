module FtpExclusionsHelper

  def product_link(product, custom_link_name=nil)
    link_to custom_link_name || product.short_name, product_path(product)
  end

  def product_version_link(product_version, custom_link_name=nil)
    link_to custom_link_name || product_version.name, product_version_path(product_version)
  end

  def package_link(package)
    # (Once I saw a package with no name so do this...)
    link_to((package.name.present? ? package.name : '-'), {
      # (For some reason links weren't working when I used the id instead of the name)
      :controller => :package,
      :action     => :show,
      :name       => (package.name.present? ? package.name : package.id),
    })
  end

  def clear_field_link
    link_to_function('&times;'.html_safe,
      # Find the input field inside this table cell and clear its value
      "$(this).closest('td').find('input').val('');",
      # Bump it left so it is over the input field
      :style => 'font-weight:bold;margin-left:-17px;color:#888;font-size:120%;',
      :class => 'nohoverunderline'
    )
  end

  def is_excluded_text(is_published, published_text='Published', excluded_text='EXCLUDED')
    content_tag :span, ( is_published ? published_text : excluded_text ), :class => ( is_published ? 'green' : 'red' )
  end
end
