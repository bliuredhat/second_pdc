module SharedApi::PackageRestrictions

  def create_restriction
    begin
      @package_restriction = PackageRestriction.new(@attr_params)
      @package_restriction.save!
      success_notice(success_message)
    rescue ActiveRecord::RecordInvalid => error
      error_notice(error)
    end
  end

  def update_restriction
    begin
      @package_restriction.update_attributes!(@attr_params)
      success_notice(success_message)
    rescue ActiveRecord::RecordInvalid => error
      error_notice(error)
    end
  end

  def delete_restriction
    @variant = @package_restriction.variant
    begin
      @package_restriction.destroy
      message = "Restriction for package '#{@package_restriction.package.name}'"\
        " has been deleted successfully."
      success_notice(message)
    rescue ActiveRecord::RecordInvalid => error
      error_notice(error)
    end
  end

  def success_message
    package = @package_restriction.package
    push_targets = @package_restriction.push_targets
    variant = @package_restriction.variant
    dists_str = !push_targets.empty? ? push_targets.map(&:name).join(', ') : 'nowhere'
    return "Package '#{package.name}' for variant '#{variant.name}' is set to push to #{dists_str} now."
  end
end