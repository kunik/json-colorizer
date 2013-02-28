require 'mongo'
require 'ostruct'

class MongoTail
  class << self
    def configure
      yield config
    end

    def config
      @config ||= OpenStruct.new({
        host: '127.0.0.1',
        port: 27017,
        database: 'application_logs',
        collection: 'logs',
        username: nil,
        password: nil,
        primary_key: :_id,
        tail_count: 10,
        limit: 100
      })
    end

    def db
      @db ||= get_db
    end

    def get_db
      client = Mongo::MongoClient.new(config.host, config.port)
      client.db(config.database).tap do |db|
        if config.username && config.password
          db.authenticate(config.username, config.password)
        end
      end
    end
  end

  attr_reader :query, :initial_count

  def initialize(query={}, skip_beginning=true)
    @query = query

    if skip_beginning
      @initial_count = collection.find(query, :fields => [config.primary_key]).count

      skip_count = initial_count - config.tail_count
    else
      skip_count = 0
    end

    query_options[:skip] = skip_count if skip_count > 0
  end

  def fetch
    cursor_class = tailable? ? TailableCursor : ManualCursor
    cursor = cursor_class.new(collection, query, query_options, config)
    resume = true

    while resume
      sleep 1
      cursor.get_portion {|doc| resume = ((yield doc) != false)}
    end

    cursor.close!
  end

  def fetch_all
    collection.find(query, query_options).sort({config.primary_key => 1}).each { |doc| yield doc }
  end

  def collection
    raise RuntimeError, "Collection '#{config.collection}' does not exist" unless db.collection_names.include?(config.collection)

    @collection ||= db.collection(config.collection)
  end

  def query_options
    @query_options ||= {}
  end

  def tailable?
    @tailable = [1, true].include?(collection.stats['capped']) unless defined?(@tailable)
    @tailable
  end

  def db
    self.class.db
  end

  def config
    self.class.config
  end
end


class TailableCursor
  attr_reader :collection, :query, :query_options, :config

  def initialize(collection, query, query_options, config)
    @collection = collection
    @query = query
    @query_options = query_options.merge(tailable: true, selector: query, order: {'$natural' => 1})
    @config = config
  end

  def get_portion
    while doc = cursor.next
      last_doc = doc
      yield last_doc
    end

    last_doc
  end

  def close!
    cursor.close
  end

  protected
  def cursor
    @cursor ||= create_cursor
  end

  def create_cursor
    Mongo::Cursor.new(collection, query_options)
  end
end

class ManualCursor < TailableCursor
  def initialize(*args)
    super
    @last_id = nil
  end

  def get_portion
    last_doc = super
    @last_id = last_doc[config.primary_key]
  end

  def close!; end

  protected
  def cursor
    unless @last_id.nil?
      query_options[:selector].merge!(config.primary_key => {:$gt => @last_id})
    end
    create_cursor
  end
end


