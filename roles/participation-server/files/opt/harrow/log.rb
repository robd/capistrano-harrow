require 'pstore'
class Log
  Entry = Struct.new(:version, :time, :data)

  def initialize(filename='/var/local/capistrano/log.pstore')
    @store = ::PStore.new(filename)
    @store.transaction do
      @store[:entries] ||= []
      @store[:version] ||= 0
    end
  end

  def version
    @store.transaction(true) do
      @store[:version] || 0
    end
  end

  def append(data)
    @store.transaction do
      current_version = @store[:version] || 0
      next_version = current_version + 1
      entry = Entry.new(next_version, Time.now, data)
      @store[:entries] << entry
      @store[:version] = next_version
    end
  end

  def each(&block)
    @store.transaction(true) do
      @store[:entries].each(&block)
    end
  end
end
