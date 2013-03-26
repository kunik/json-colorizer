require 'colorize'

class JsonColorizer
  def initialize(schema)
    @schema = schema
    @schema_keys = @schema.keys
    @other = schema.delete(:_other)
  end

  def format(data)
    parts = []
    @schema.each do |key, formatters|
      formatters = [formatters] unless formatters.is_a?(Array)
      parts << apply_formatters(data.fetch(key, data.fetch(key.to_s, nil)), formatters)
    end

    unless @other.nil?
      parts << data.select{ |k, v| !@schema_keys.include?(k) }.to_s
    end

    parts.join(' ')
  end

  def apply_formatters(data, formatters)
    return '' if data.nil?

    formatters.reduce(data) do |output, formatter|
      case formatter
      when Proc
        formatter.call(output)
      when Symbol
        self.send(formatter, output)
      else
        output
      end
    end
  end

  String::COLORS.each_key do | key |
    next if key == :default

    define_method key do |s|
      self.colorize(s, :color => key)
    end

    define_method "on_#{key}" do |s|
      self.colorize(s, :background => key)
    end
  end

  def colorize(s, color_options)
    s.to_s.colorize(color_options)
  end
end

