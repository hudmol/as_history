class History < Sequel::Model(:history)

  def self.ensure_current_versions(objs, jsons)
    latest_versions = db[:history]
      .filter(:model => objs.first.class.table_name.to_s)
      .filter(:record_id => objs.map{|o| o.id})
      .group(:lock_version)
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
                      :json => ASUtils.to_json(json),
                      )
        rescue Sequel::UniqueConstraintViolation
          # Someone beat us to it. No worries!
        end
      end
    end
  end


  def self.uri_for(obj, version = nil)
    uri(obj.class.table_name.to_s, obj.id, version)
  end


  def self.uri(model, id, version = nil)
    '/history/' + [model, id, version].compact.join('/')
  end


  def self.versions(model, id)
    History.new(model, id).versions
  end


  def self.version(model, id, version, opts = {})
    History.new(model, id).version(version)
  end


  def self.version_at(model, id, time)
    History.new(model, id).version_at(time)
  end


  def initialize(model, id)
    @model = model
    @id = id
    @ds = db[:history].filter(:model => @model, :record_id => @id)
  end


  def versions
    @ds.select(:lock_version)
       .map { |history| History.uri(@model, @id, history[:lock_version]) }
  end


  def version(version)
    ASUtils.json_parse(_find_version(@ds.filter(:lock_version => version))[:json])
  end


  def version_at(time)
    ASUtils.json_parse(_find_version(@ds.where{user_mtime < time}.reverse(:lock_version))[:json])
  end


  private

  def _find_version(ds)
    ds.first || raise("No version found!")
  end

end
