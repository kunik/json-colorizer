require 'optparse'
require 'optparse/time'
require 'ostruct'

class Options
  def initialize(args)
    @args = args
    @options = OpenStruct.new
    @options.from = Time.now.utc
    @tail = true

    parse_args!
  end

  def parse_args!
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: logs [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-f", "--from [TIME]", Time, "Start searching from time") do |time|
        @options.from = time
      end

      opts.on("-t", "--to [TIME]", Time, "Search until time") do |time|
        @options.to = time
      end

      opts.on("-T", "--tags [key:value]", Array, "Tags you are searching for") do |data|
        @options.tags = Hash[data.map do |m|
          k,v = m.split(':')
          k = "tags.#{k.strip}"
          if v == '?'
            v = {'$exists' => 1}
          else
            v = v.strip

            if v.to_i.to_s == v
              v = v.to_i
            end
          end
          [k, v]
        end]
      end

      opts.on_tail("-o", "--one-time", "One-time query. Do not append the results") do
        @tail = false
      end

      opts.separator ""
      opts.separator "Common options:"

      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    parser.parse! @args
  end

  def tail?
    @tail
  end

  def query
    q = { 'time' => { '$gt' => @options.from.utc } }
    q['time']['$lte'] = @options.to.utc if @options.to
    q.merge!(@options.tags) if @options.tags
    q['message'] = Regexp.new(@args.join(' ')) unless @args.empty?
    q
  end

  def schema
    {
      severity: [
        lambda {|item| item[0].upcase},
        :red
      ],
        time: [
          :datetime,
          :green
      ],
        tags: [
          lambda do |item|
            parts = ["[#{item['pid']}:#{item['uuid']}]"]

            if item['user_id']
              parts << "U##{item['user_id']}"
            end

            other = item.reject {|k, v| ['pid', 'uuid', 'user_id'].include?(k)}
            unless other.empty?
              parts << other.to_s
            end

            parts.join(' ')
          end,
          :white
      ],
        message: :message
    }
  end
end
