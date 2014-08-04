class Fluent::DeriveOutput < Fluent::Output
  # Define `log` method for v0.10.42 or earlier
  unless method_defined?(:log)
    define_method("log") { $log }
  end

  Fluent::Plugin.register_output('derive', self)

  KEY_MAX_NUM = 20
  (1..KEY_MAX_NUM).each {|i| config_param "key#{i}".to_sym, :string, :default => nil }
  config_param :key_pattern, :string, :default => nil
  config_param :tag, :string, :default => nil
  config_param :add_tag_prefix, :string, :default => nil
  config_param :remove_tag_prefix, :string, :default => nil
  config_param :min, :integer, :default => nil
  config_param :max, :integer, :default => nil
  config_param :time_unit_division, :bool, :default => true

  # for test
  attr_reader :key_pattern
  attr_reader :key_pattern_adjustment
  attr_reader :keys
  attr_reader :prev

  def configure(conf)
    super

    if @key_pattern
      key_pattern, @key_pattern_adjustment = @key_pattern.split(/ +/, 2)
      @key_pattern_adjustment = parse_adjustment(@key_pattern_adjustment)
      @key_pattern = Regexp.compile(key_pattern)
    else
      @keys = {}
      (1..KEY_MAX_NUM).each do |i|
        next unless conf["key#{i}"] 
        key, adjustment = conf["key#{i}"].split(/ +/, 2)
        adjustment = parse_adjustment(adjustment)
        @keys[key] = adjustment
      end
    end
    raise Fluent::ConfigError, "Either of `key_pattern` or `key1` must be specified" if (@key_pattern.nil? and @keys.empty?)

    raise Fluent::ConfigError, "Either of `tag`, `add_tag_prefix`, or `remove_tag_prefix` must be specified" if (@tag.nil? and @add_tag_prefix.nil? and @remove_tag_prefix.nil?)
    @tag_prefix = "#{@add_tag_prefix}." if @add_tag_prefix
    @tag_prefix_match = "#{@remove_tag_prefix}." if @remove_tag_prefix
    @tag_proc =
      if @tag
        Proc.new {|tag| @tag }
      elsif @tag_prefix and @tag_prefix_match
        Proc.new {|tag| "#{@tag_prefix}#{lstrip(tag, @tag_prefix_match)}" }
      elsif @tag_prefix_match
        Proc.new {|tag| lstrip(tag, @tag_prefix_match) }
      elsif @tag_prefix
        Proc.new {|tag| "#{@tag_prefix}#{tag}" }
      else
        Proc.new {|tag| tag }
      end

    raise Fluent::ConfigError, "`max` must be greater than `min`" if (@min && @max && @min >= @max)

    @prev = {}
    @mutex = Mutex.new
  rescue => e
    raise Fluent::ConfigError, "#{e.class} #{e.message} #{e.backtrace.first}"
  end

  def start
    super
  end

  def shutdown
    super
  end

  def emit(tag, es, chain)
    emit_tag = @tag_proc.call(tag)

    if @key_pattern
      es.each do |time, record|
        record.each do |key, value|
          next unless key =~ @key_pattern
          value = value.to_i
          prev_time, prev_value = get_prev_value(tag, key)
          unless prev_time && prev_value
            save_to_prev(time, tag, key, value)
            record[key] = nil
            next
          end
          # adjustment
          rate = calc_rate(tag, key, value, prev_value, time, prev_time, @key_pattern_adjustment)
          rate = truncate_min(rate, @min) if @min
          rate = truncate_max(rate, @max) if @max
          # Set new value
          record[key] = rate
          save_to_prev(time, tag, key, value)
        end
        Fluent::Engine.emit(emit_tag, time, record)
      end
    else #keys
      es.each do |time, record|
        @keys.each do |key, adjustment|
          next unless  value = record[key]
          value = value.to_i
          prev_time, prev_value = get_prev_value(tag, key)
          unless prev_time && prev_value
            save_to_prev(time, tag, key, value)
            record[key] = nil
            next
          end
          # adjustment
          rate = calc_rate(tag, key, value, prev_value, time, prev_time, adjustment)
          rate = truncate_min(rate, @min) if @min
          rate = truncate_max(rate, @max) if @max
          # Set new value
          record[key] = rate
          save_to_prev(time, tag, key, value)
        end
        Fluent::Engine.emit(emit_tag, time, record)
      end
    end

    chain.next
  rescue => e
    log.warn e.message
    log.warn e.backtrace.join(', ')
  end

  # @return [Array] time, value
  def get_prev_value(tag, key)
    @prev["#{tag}:#{key}"] || []
  end

  def save_to_prev(time, tag, key, value)
    @mutex.synchronize { @prev["#{tag}:#{key}"] = [time, value] }
  end

  private

  def lstrip(string, substring)
    string.index(substring) == 0 ? string[substring.size..-1] : string
  end

  def parse_adjustment(str)
    case str
    when /^\*(\d+)$/
      ['*', $1.to_i]
    when /^\/(\d+)$/
      ['/', $1.to_i]
    else
      nil
    end
  end

  def calc_rate(tag, key, cur_value, prev_value, cur_time, prev_time, adjustment = nil)
    if cur_time - prev_time <= 0
      log.warn "Could not calculate the rate. multiple input less than one second or minus delta of seconds on tag=#{tag}, key=#{key}"
      return nil
    end
    if @time_unit_division
      rate = (cur_value - prev_value)/(cur_time - prev_time)
    else
      rate = cur_value - prev_value
    end
    if adjustment && adjustment[0] == '*'
      rate * adjustment[1]
    elsif adjustment && adjustment[0] == '/'
      rate / adjustment[1]
    else
      rate
    end
  end

  def truncate_min(value, min)
    return nil unless value
    (value < min) ? min : value
  end

  def truncate_max(value, max)
    return nil unless value
    (value > max) ? max : value
  end


end

