class Fluent::DeriveOutput < Fluent::Output
  Fluent::Plugin.register_output('derive', self)

  KEY_MAX_NUM = 20
  (1..MAPPING_MAX_NUM).each {|i| config_param "key#{i}".to_sym, :string, :default => nil }
  config_param :key_pattern, :string, :default => nil
  config_param :tag, :string, :default => nil
  config_param :add_tag_prefix, :string, :default => nil
  config_param :remove_tag_prefix, :string, :default => nil

  # for test
  attr_reader :keys
  attr_reader :key_pattern

  def initialize
    super
    @prev = {}
  end

  def configure(conf)
    super

    if @key_pattern
      key_pattern, @key_pattern_adjustment = @key_pattern.split(/ +/, 2)
      @key_pattern = Regexp.compile(key_pattern)
    else
      @keys = {}
      (1..KEY_MAX_NUM).each do |i|
        next unless conf["key#{i}"] 
        key, adjustment = conf["key#{i}"].split(/ +/, 2)
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
    if @key_pattern
      es.each do |time, record|
        record.each do |key, value|
          next unkess key =~ @key_pattern
          prev_time, prev_value = get_prev_value(tag, key)
          unless prev_time && prev_value
            save_to_prev(time, tag, key, value)
            record[key] = nil
            next
          end
          # adjustment
          rate = (value - prev_value)/(prev_time - time)
          if @key_pattern_adjustment
            rate = eval("rate #{@key_pattern_adjustment}")
          end
          # Set new value
          record[key] = rate
          save_to_prev(time, tag, key, value)
        end
      end
    else #keys
      es.each do |time, record|
        @keys.each do |key, adjustment|
          next unless  value = record[key]
          unless prev_time && prev_value
            save_to_prev(time, tag, key, value)
            record[key] = nil
            next
          end
          # adjustment
          rate = (value - prev_value)/(prev_time - time)
          if @key_pattern_adjustment
            rate = eval("rate #{@key_pattern_adjustment}")
          end
          # Set new value
          record[key] = rate
          save_to_prev(time, tag, key, value)
        end
      end
    end
    emit_tag = @tag_proc.call(tag)
    Engine.emit(emit_tag, time, record)
  end

  # @return [Array] time, value
  def get_prev_record(tag, key)
    @prev["#{tag}:#{key}"] || []
  end

  def save_to_prev(time, tag, key, value)
    @mutex.synchronize { @prev["#{tag}:#{key}"] = [time, value] }
  end

  private

  def lstrip(string, substring)
    string.index(substring) == 0 ? string[substring.size..-1] : string
  end

end

