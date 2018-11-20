require 'zlib'

class History < Sequel::Model(:history)

  def self.fields
    [
     :record_id,
     :model,
     :lock_version,
     :uri,
     :created_by,
     :last_modified_by,
     :create_time,
     :system_mtime,
     :user_mtime,
     :json,
    ]
  end

  def self.audit_fields
    [
     :lock_version,
     :created_by,
     :last_modified_by,
     :create_time,
     :system_mtime,
     :user_mtime,
    ]

  end

  class VersionNotFound < StandardError; end

  def self.ensure_current_versions(objs, jsons)
    return if objs.empty?
    latest_versions = db[:history]
      .filter(:model => objs.first.class.table_name.to_s)
      .filter(:record_id => objs.map{|o| o.id})
      .group(:record_id)
      .select_hash(:record_id, Sequel.function(:max, :lock_version).as(:max_version))

    jsons.zip(objs).each do |json, obj|
      unless latest_versions[obj.id] && latest_versions[obj.id] == obj.lock_version
        begin
          self.insert(
                      :record_id => obj.id,
                      :model => obj.class.table_name.to_s,
                      :lock_version => obj.lock_version,
                      :uri => json[:uri],
                      :created_by => obj.created_by,
                      :last_modified_by => obj.last_modified_by,
                      :create_time => obj.create_time,
                      :system_mtime => obj.system_mtime,
                      :user_mtime => obj.user_mtime,
                      :json => Sequel::SQL::Blob.new(Zlib::Deflate.deflate(ASUtils.to_json(json))),
                      )
        rescue Sequel::UniqueConstraintViolation
          # Someone beat us to it. No worries!
        end
      end
    end
  end


  def self.record_delete(obj)
    uri_hash = obj.respond_to?(:repo_id) ? {:repo_id => obj.repo_id} : {}
    self.insert(
                :record_id => obj.id,
                :model => obj.class.table_name.to_s,
                :lock_version => obj.lock_version + 1,
                :uri => obj.class.my_jsonmodel(true).uri_for(obj.id, uri_hash),
                :created_by => obj.created_by,
                :last_modified_by => obj.last_modified_by,
                :create_time => obj.create_time,
                :system_mtime => obj.system_mtime,
                :user_mtime => Time.now,
                :json => Sequel::SQL::Blob.new(Zlib::Deflate.deflate(ASUtils.to_json({:deleted => true}))),
                )
  end


  def self.uri_for(obj, version = nil)
    uri(obj.class.table_name.to_s, obj.id, version)
  end


  def self.uri(model, id, version = nil)
    '/history/' + [model, id, version].compact.join('/')
  end


  def self.uri_for_uri_at(time, uri)
    version = db[:history].filter(:uri => uri).where{user_mtime <= time}.reverse(:user_mtime).first
    version ? uri(version[:model], version[:record_id], version[:lock_version]) : uri
  end


  def self.versions(model, id)
    History.new(model, id).versions
  end


  def self.version(model, id, version, opts = {})
    History.new(model, id).version(version, opts)
  end


  def self.version_at(model, id, time, opts = {})
    History.new(model, id).version_at(time, opts)
  end


  def self.diff(model, id, a, b)
    History.new(model, id).diff(a, b)
  end


  def self.recent(limit = 10)
    Hash[db[:history].reverse(:user_mtime)
           .select(*fields.reject{|f| f == :json}).limit(limit).all
           .map{|r| [History.uri(r[:model], r[:record_id], r[:lock_version]), r]}]
  end


  def self.recent_for_user(user, limit = 10)
    Hash[db[:history].filter(:last_modified_by => user).reverse(:user_mtime)
           .select(*fields.reject{|f| f == :json}).limit(limit).all
           .map{|r| [History.uri(r[:model], r[:record_id], r[:lock_version]), r]}]
  end


  ###

  class Version

    def self.list_for(history)
      Hash[history.ds.reverse(:lock_version)
             .select(*History.fields.reject{|f| f == :json}).all
             .map {|r| [History.uri(r[:model], r[:record_id], r[:lock_version]), r]}]
    end


    def initialize(history, version)
      @history = history
      if version.to_i.to_s == version.to_s
        @version = version
        @data = _version_or_die(@history.ds.filter(:lock_version => version))
      else
        @time = version
        @data = _version_or_die(@history.ds.where{user_mtime <= version}.reverse(:lock_version))
      end
    end


    def data
      {History.uri(@data[:model], @data[:record_id], @data[:lock_version]) => @data.reject{|f| f == :json}}
    end


    def version
      @data[:lock_version]
    end

    def time
      @data[:user_mtime]
    end

    def json(convert_uris = true)
      ASUtils.json_parse(convert_uris ? _convert_uris(_inflated_json) : _inflated_json)
    end


    private

    def _version_or_die(ds)
      ds.first || raise(History::VersionNotFound.new)
    end


    def _inflated_json
      Zlib::Inflate.inflate(Sequel::SQL::Blob.new(@data[:json]))
    end


    def _convert_uris(json)
      time = @time || @data[:user_mtime]
      json.gsub(/\"((\/[^\/ \"]+)+)/) {|m| '"' + History.uri_for_uri_at(time, $1)}
    end

  end


  ###


  attr_reader :ds

  def initialize(model, id)
    @model = model
    @id = id
    @ds = db[:history].filter(:model => @model, :record_id => @id)
  end


  def versions
    Version.list_for(self)
  end


  def version(version)
    Version.new(self, version)
  end


  def diff(a, b)
    diffs = {:_changes => {}, :_adds => {}, :_removes => {}}
    return diffs if a == b

    from_json = version([a,b].min).json(false)
    to_json = version([a,b].max).json(false)

    (to_json.keys - from_json.keys).each{|k| diffs[:_adds][k] = to_json[k]}
    (from_json.keys - to_json.keys).each{|k| diffs[:_removes][k] = from_json[k]}

    (to_json.keys & from_json.keys).each do |k|
      next if History.audit_fields.include?(k.intern)
      next if from_json[k] == to_json[k]

      if from_json[k].is_a? Array
        ca = []
        fa = from_json[k] + (Array.new([to_json[k].length - from_json[k].length, 0].max))
        fa.zip(to_json[k]) do |f, t|
          if f && t
            hd = _nested_hash_diff(f,t)
            ca.push(hd) unless hd.empty?
          else
            ca.push({:_from => f, :_to => t})
          end
        end
        diffs[:_changes][k] = ca unless ca.empty?
      elsif to_json[k].is_a? Hash
        hd = _nested_hash_diff(from_json[k], to_json[k])
        diffs[:_changes][k] = hd unless hd.empty?
      else
        diffs[:_changes][k] = {:_from => from_json[k], :_to => to_json[k]}
      end
    end

    diffs    
  end


  private

  def _nested_hash_diff(from, to)
    out = {}
    (from.keys | to.keys).each do |k|
      next if History.audit_fields.include?(k.intern)
      next if from[k] == to[k]
      out[k] = {:_from => from[k], :_to => to[k]}
    end
    out
  end

end
