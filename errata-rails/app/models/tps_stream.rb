class TpsStream < ActiveRecord::Base
  require 'tps/tps_exceptions'

  belongs_to :tps_stream_type
  belongs_to :tps_variant
  belongs_to :parent, :class_name => 'TpsStream', :foreign_key => 'parent_id'

  validates_presence_of :name, :tps_stream_type_id, :tps_variant_id

  # name is product version that returned by Tps server, such as RHEL-7.0
  alias_attribute :product_version, :name
  alias_attribute :variant_id, :tps_variant_id
  alias_attribute :stream_type_id, :tps_stream_type_id

  def full_name
    stream_type_name = tps_stream_type ? tps_stream_type.name : 'Main'
    [product_version, stream_type_name, tps_variant.name].join("-")
  end

  def to_hash(fields = nil)
    return self.attributes if !fields
    fields.each_with_object({}) do |field,h|
      h[field.to_s] = self.send(field.to_s)
    end
  end

  def self.get_by_full_name(tps_stream_full_name)
    errors = HashList.new
    matches = tps_stream_full_name.match(%r{(.+)-([^-]+)-([^-]+)$}i)
    if matches.nil?
      errors[:fatal] << ArgumentError.new("'#{tps_stream_full_name}' is invalid.")
      return [nil, errors]
    end

    data = get_tps_stream_type_and_tps_variant(matches[2], matches[3])
    if (fatal_errors = data[:errors]).any?
      errors[:fatal].concat(fatal_errors)
      return [nil, errors]
    end

    tps_stream = TpsStream.where(
      :name => matches[1],
      :tps_stream_type_id => data[TpsStreamType],
      :tps_variant_id => data[TpsVariant]
    ).first_or_initialize

    if tps_stream.new_record?
      errors[:warn] << Tps::TpsStreamNotFound.new(tps_stream_full_name)
    elsif !tps_stream.active?
      errors[:warn] << Tps::TpsStreamNotActive.new(tps_stream_full_name)
    end
    [tps_stream, errors]
  end

  def self.get_by_errata_variant(errata_variant)
    errors = HashList.new
    rhel_variant = errata_variant.is_parent? ? errata_variant : errata_variant.rhel_variant
    # Simply return nil without error because there is already a rhel variant validation.
    return [nil, errors] unless rhel_variant.present? && rhel_variant.name.present?
    #<MatchData
    # 0: "7Server-LE-7.0.Z"
    # 1: "7"
    # 2: "Server-LE"
    # 3: "Server"
    # 4: "-LE"
    # 5: "LE"
    # 6: "-7.0.Z"
    # 7: "7.0"
    # 8:".Z"
    # 9: "Z"
    # >
    #
    #<MatchData
    # 0: "7Server-7.0.Z"
    # 1: "7"
    # 2: "Server"
    # 3: "Server"
    # 4: nil
    # 5: nil
    # 6: "-7.0.Z"
    # 7: "7.0"
    # 8: ".Z"
    # 9: "Z"
    # >
    #
    # Element 1 = X stream, e.g. 6, 7
    # Element 3 = TPS variant
    # Element 7 = Y stream, e.g. 6.5, 7.1
    # Element 9 = TPS stream type
    matches = rhel_variant.name.match(%r{^(\d)(([A-Z]+)(-([A-Z]+))?)(-([0-9.]+)(\.([A-Z]+))?)?$}i)
    if matches.nil?
      errors[:fatal] << ArgumentError.new("cannot be determined. Please make sure '#{rhel_variant.name}' is a valid variant name.")
      return [nil, errors]
    end
    # RHEL
    product = rhel_variant.product.short_name
    x_stream = matches[1]
    y_stream = matches[7].present? ? matches[7] : x_stream
    tps_variant_name = matches[3]
    # FIXME: EUS is not a valid stream type in TPS server. Need to map it to Z stream. E.g. variant 5Server-5.6.EUS
    # Might need a way better way to do this, instead of hard coding.
    tps_stream_type_name = matches[9] == "EUS" ? "Z" : matches[9]
    # Get Main stream. E.g. RHEL-7
    main_pv_name = [product, x_stream].join("-")
    # E.g. 'RHEL-7.0' + 'Z' = 'RHEL-7.0-Z'
    pv_name = [product, y_stream].join("-")

    data = get_tps_stream_type_and_tps_variant(tps_stream_type_name, tps_variant_name)
    # Error if TPS stream type doesn't exist. Examples of TPS stream type are 'Main', 'Z', 'AUS' etc
    # Error if TPS variant doesn't exist. Examples of TPS variant are 'Server', 'Client' etc.
    if (fatal_errors = data[:errors]).any?
      errors[:fatal].concat(fatal_errors)
      return [nil, errors]
    end
    tps_variant = data[TpsVariant]
    tps_stream_type = data[TpsStreamType]

    # Get list of applicable TPS streams based on product version and TPS variant. E.g. RHEL-7.0-*-Server
    available_tps_streams = self.where(:name => [pv_name, main_pv_name].uniq, :tps_variant_id => tps_variant)

    # Let says TPS stream type == 'Z', then the TPS stream will be 'RHEL-7.0-Z-Server'
    if tps_stream_type
      tps_stream = available_tps_streams.select{|s| s.tps_stream_type_id == tps_stream_type.id}.first
    end

    # If Z-stream TPS stream is not exist yet, than use MAIN stream instead
    if tps_stream_type.nil? || tps_stream.nil? && tps_stream_type.is_zstream?
      # Parent id 1 is 'None'. TPS server seems to consider 'None' as top level. All 'Main' streams
      # are currently inheriting it.
      tps_stream = available_tps_streams.select{|s| s.parent_id.nil? || s.parent_id == 1 }.first
    end

    # Check if the TPS stream is still active in TPS server
    if tps_stream && !tps_stream.active?
      errors[:warn] << Tps::TpsStreamNotActive.new(tps_stream.full_name)
    # The TPS stream is valid but doesn't exist in TPS server
    elsif tps_stream.nil?
      tps_stream = TpsStream.new(:name => pv_name, :tps_variant => tps_variant, :tps_stream_type => tps_stream_type)
      errors[:warn] << Tps::TpsStreamNotFound.new(tps_stream.full_name)
    end
    return [tps_stream, errors]
  end

  private

  def self.get_tps_stream_type_and_tps_variant(tps_stream_type_name, tps_variant_name)
    [
      [TpsStreamType, Tps::TpsStreamTypeNotFound, tps_stream_type_name],
      [TpsVariant, Tps::TpsVariantNotFound, tps_variant_name]
    ].each_with_object({}) do |(klass, exception, name),data|
      next if name.nil?
      # Case insensitive, work for both mysql and postgresql (i think)
      data[klass] = klass.where("lower(name) = ?", name.downcase).first
      data[:errors] ||= []
      data[:errors] << exception.new(name) if data[klass].nil?
    end
  end
end
