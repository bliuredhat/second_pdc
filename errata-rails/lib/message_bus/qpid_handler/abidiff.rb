module MessageBus::QpidHandler::Abidiff
  extend ActiveSupport::Concern

  included do
    add_subscriptions(:abidiff_subscriptions)
  end

  def abidiff_subscriptions
    exchange = 'eso.topic'
    topic_prefix = Qpid::ABIDIFF_TOPIC_PREFIX

    topic_subscribe(exchange, "#{topic_prefix}.started") do |content, msg|
      puts "abi started"
      run = find_or_create_abidiff_run(content)
      output(content,msg)
    end

    topic_subscribe(exchange, "#{topic_prefix}.failed") do |content, msg|
      puts "abi failed"
      run = find_or_create_abidiff_run(content)
      output(content,msg)
    end

    topic_subscribe(exchange, "#{topic_prefix}.complete") do |content, msg|
      puts "abi complete"
      run = find_or_create_abidiff_run(content)
      output(content,msg)
    end
  end

  def find_or_create_abidiff_run(content)
    begin
      errata_id = content['errata_id']
      raise "No such errata id #{errata_id} for abidiff message" unless Errata.exists?(errata_id)
      errata = Errata.find(errata_id)
      build = BrewBuild.find_by_nvr(content['build'])
      raise "No such build: #{content['build']}" unless build
      unless errata.errata_brew_mappings.where(:brew_build_id => build).exists?
        raise "Build #{build.nvr} is not attached to advisory #{errata_id}"
      end

      if AbidiffRun.exists?(content['id'])
        run = AbidiffRun.find(content['id'])
      else
        run = AbidiffRun.new(:errata => errata)
        run.id = content['id']
        run.brew_build = build
      end
      run.status = content['status']
      run.result = content['result']
      run.timestamp = Time.parse content['timestamp']
      run.message = content['message']
      run.save!
      return run
    rescue => e
      MBUSLOG.error "Error processing message for run #{content['id']}"
      MBUSLOG.error e.message
      return nil
    end
  end

end
