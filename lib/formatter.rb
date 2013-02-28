require 'colorize'

class Formatter

  def initialize(schema)
    @schema = schema
    @schema_keys = @schema.keys
    @other = schema.delete(:_other)
  end

  def pretty_print(data)
    parts = []
    @schema.each do |k, formatters|
      key = k.to_s
      formatters = [formatters] unless formatters.is_a?(Array)
      parts << apply_formatters(data[key], formatters)
    end

    unless @other.nil?
      parts << data.select{ |k, v| !@schema_keys.include?(k) }.to_s
    end

    puts parts.join(' ')
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

  def datetime(d)
    d.to_s
  end

  def message(s)
    s.to_s
  end
end
