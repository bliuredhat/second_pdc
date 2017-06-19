module Tps
  class SyncTpsStreams

    def self.sync
      runs = [
        {
          :type => 'variant',
          :klass => TpsVariant,
          :tps_url => "http://#{Tps::TPS_SERVER}/variants.json",
          :fields => %w[id name],
        },
        {
          :type => 'stream_type',
          :klass => TpsStreamType,
          :tps_url => "http://#{Tps::TPS_SERVER}/stream_types.json",
          :fields => %w[id name],
        },
        {
          :type => 'stream',
          :klass => TpsStream,
          :tps_url => "http://#{Tps::TPS_SERVER}/streams.json",
          :fields => %w[id name variant_id stream_type_id active parent_id],
        },
      ]

      runs.each_with_object({}) do |r,h|
        klass = r[:klass]
        h[klass] = update_data(r)
      end
    end

    def self.update_data(args)
      klass = args[:klass]
      fields = args[:fields]

      old_data = klass.all.map{|obj| obj.respond_to?(:to_hash) ? obj.to_hash(fields) : obj.attributes}.to_set
      new_data = get_tps_data(args).to_set

      to_be_created = new_data - old_data
      to_be_deleted = old_data - new_data

      deleted = 0
      unless to_be_deleted.empty?
        results = klass.where("id in (?)", to_be_deleted.map{|d| d['id']}).destroy_all
        deleted = results.size
      end

      created = 0
      to_be_created.each do |data|
        begin
          klass.create!(data, :without_protection => true)
          created += 1
        rescue StandardError => ex
          # TPS server has a TPS stream called 'NONE' with blank variant and
          # blank stream type. This will be skipped due to the validation errors.
          # Catch and log any error, such as foreign key error. Might happen if TPS server
          # has bad data integrity.
          TPSLOG.error "#{klass.name}: #{ex}"
        end
      end

      return { 'created' => created, 'deleted' => deleted }
    end

    def self.get_tps_data(args)
      tps_url = args[:tps_url]
      type = args[:type]
      fields = args[:fields]
      error = Hash.new
      begin
        response = Net::HTTP.get_response(URI.parse(tps_url))
        response.value
        data = response.body
        return ActiveSupport::JSON.decode(data).map{ |h| h[type].slice(*fields) }
      rescue Net::HTTPServerException => e
        error = {:handler => e, :message => "Error response from TPS server: #{e.message}."}
      rescue SocketError => e
        # catch invalid url here
        error = {:handler => e, :message => %Q{The url "#{tps_url}" is unreachable.}}
      rescue Exception => e
        # catch Other errors
        error = {:handler => e, :message => "Failed to connect to TPS server: #{e.message}."}
      end

      # check if there is any error been raised
      if !error.empty?
        TPSLOG.error error[:message]
        TPSLOG.error error[:handler].backtrace.join("\n")
        raise e, error[:message]
      end
    end

    def perform
      TPSLOG.info "Syncing information with TPS server (#{Tps::TPS_SERVER})..."
      self.class.sync
      TPSLOG.info "Sync complete."
    end

    def next_run_time
      # Twice a day
      13.hours.from_now
    end

    def rerun?
      true
    end

    def self.enqueue_once
      obj = self.new
      id = Delayed::Job.enqueue_once obj, 0, obj.next_run_time
      return id
    end
  end
end
