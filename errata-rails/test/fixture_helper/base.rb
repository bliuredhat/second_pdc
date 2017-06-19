class ActiveRecord::Base

  # Returns this record formatted as a YAML snippet, suitable for appending
  # to a fixture file.
  def to_fixture
    id = self.id
    model_name = self.class.model_name
    yml = {"#{model_name.underscore}_#{id}" => self.attributes}.to_yaml
    yml.sub!(/^---.*?\n/m, '').gsub!(/\s+$/, '')
  end

  # Writes this record to the end of the appropriate fixture file (if that file
  # doesn't already contain the record).
  #
  # May traverse some relationships to write (some of) the records this one
  # depends on.
  def write_fixture!
    return if self._recursing_fixture?

    self._write_fixture_recurse

    if have_fixture?
      FixtureHelper.log "Fixture #{self.class.name} #{self.id} already exists"
      return
    end

    yml = self.to_fixture
    file = self._fixture_table_file

    File.open(file, 'a+') do |io|
      prefix = ''
      begin
        io.seek(-1, IO::SEEK_END)
        if io.read(1) != "\n"
          prefix = "\n"
        end
      rescue
        # seek/read fails if file didn't exist
      end
      io.puts("#{prefix}#{yml}")
    end

    FixtureHelper.log "Appended to #{file}:\n#{yml}"
  end

  # Returns true if this record already exists in the appropriate fixture file.
  #
  # Note this is based on a heuristic which may be wrong in certain cases.
  def have_fixture?
    lookfor = " #{self.class.primary_key}: #{self.id}"
    File.open(_fixture_table_file, 'r') do |io|
      io.each_line do |line|
        return true if line.include?(lookfor)
      end
    end
    false
  end

  def _write_fixture_recurse
    begin
      ActiveRecord::Base._recursing_fixture[self.class][self.id] = true
      _fixture_traverse_keys.each do |key|
        next unless self.respond_to?(key)

        val = self.send(key)
        next if val.nil?

        Array.wrap(val).each(&:write_fixture!)
      end
    ensure
      ActiveRecord::Base._recursing_fixture[self.class].delete(self.id)
    end
  end

  def _fixture_table_file
    Rails.root.join('test', 'fixtures', "#{self.class.table_name}.yml")
  end

  def _fixture_traverse_keys
    []
  end

  @@_recursing_fixture = Hash.new{|h,k| h[k] = Hash.new}

  def self._recursing_fixture
    @@_recursing_fixture
  end

  def _recursing_fixture?
    ActiveRecord::Base._recursing_fixture[self.class][self.id]
  end
end
