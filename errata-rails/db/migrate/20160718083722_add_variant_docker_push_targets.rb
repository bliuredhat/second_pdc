class AddVariantDockerPushTargets < ActiveRecord::Migration
  def up
    ActiveRecord::Base.transaction do
      all_missing_docker_variant_push_targets.each(&:save!)
    end
  end

  def down
    # Do nothing, we can't distinguish between new and old variant
    # push targets, and there is no harm keeping them there.
  end

  def all_missing_docker_variant_push_targets
    [
      missing_docker_variant_push_targets(:cdn, :cdn_docker),
      missing_docker_variant_push_targets(:cdn_stage, :cdn_docker_stage)
    ].flatten
  end

  #
  # Returns array of missing VariantPushTargets, one for each
  # variant already configured for cdn_target, for product versions
  # that are already configured for the docker_target.
  #
  def missing_docker_variant_push_targets(cdn_push_type, docker_push_type)
    cdn_target = PushTarget.find_by_push_type(cdn_push_type)
    docker_target = PushTarget.find_by_push_type(docker_push_type)
    to_create = []

    # Find product version level push targets for docker_target
    ActivePushTarget.where(:push_target_id => docker_target.id).each do |apt|
      if apt.variant_push_targets.none?
        # No variant level push targets exist, need to be created
        cpt = ActivePushTarget.find_by_product_version_id_and_push_target_id(apt.product_version_id, cdn_target.id)
        next if cpt.nil?

        # Create a new docker push target for each variant
        # that already has the equivalent CDN push target
        to_create << cpt.variant_push_targets.map do |t|
          VariantPushTarget.new(:variant => t.variant, :push_target => docker_target, :active_push_target => apt)
        end
      end
    end
    to_create.flatten
  end
end
