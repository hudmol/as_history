require 'zlib'
require 'digest/sha1'

class History < Sequel::Model(:history)

  def self.register_model(model)
    models.push(model)

    model.my_jsonmodel.schema['properties']['history'] = {
      'type' => 'object',
      'subtype' => 'ref',
      'properties' => {
        'ref' => {
          'type' => 'uri',
        }
      }
    }

    model_map[model] = {}

    model.prepend(Auditable)
  end

  def self.models
    @models ||= []
    @models
  end

  def self.model_map
    @model_map ||= {}
    @model_map
  end

  def self.fields
    @fields ||=
      [
       :record_id,
       :model,
       :revision,
       :lock_version,
       :uri,
       :label,
       :created_by,
       :last_modified_by,
       :create_time,
       :system_mtime,
       :user_mtime,
       :json,
      ]
  end

  def self.diff_skip_fields
    @diff_skip_fields ||=
      [
       :jsonmodel_type,
       :revision,
       :lock_version,
       :created_by,
       :last_modified_by,
       :create_time,
       :system_mtime,
       :user_mtime,
      ]

  end

  def self.add_diff_skip_field(field)
    diff_skip_fields # make sure it's initialized
    @diff_skip_fields << field
  end

  def self.add_model_map(model, map)
    model_map # make sure it's initialized
    @model_map[model] = @model_map[model].merge(map)
  end

  def self.datetime_fields
    @datetime_fields ||=
      [
       :create_time,
       :system_mtime,
       :user_mtime,
      ]
  end


  class VersionNotFound < StandardError; end


  def self.ensure_system_version
    config = AppConfig.dump_sanitized
    config_digest = AppConfig.digest

    begin
      last_seen = SystemVersion.new
    rescue VersionNotFound
      # no records in the system version table - no worries!
    end

    @current_system_version =
      if last_seen && last_seen.data[:version] == ASConstants.VERSION && last_seen.data[:config_digest] == config_digest
        last_seen
      else
        sys_version = {
          :version => ASConstants.VERSION,
          :config_digest => config_digest,
          :first_seen => Time.now,
          :config => ASUtils.to_json(config),
        }
        db[:history_system_version].insert(sys_version)
        
        SystemVersion.new
      end
  end


  def self.current_system_version
    (@current_system_version || ensure_system_version).data
  end


  def self.system_version_at(time = false)
    return current_system_version unless time
    SystemVersion.new(normalize_time(time)).data
  end


  def self.system_version_for(model, id, version)
    SystemVersion.new(History.new(model, id).version(version).time).data
  end


  def self.system_versions
    db[:history_system_version]
      .reverse(:first_seen)
      .select(*SystemVersion.fields.reject{|f| f == :config})
      .all.map{|r| SystemVersion.from_row(r)}
  end


  def self.clean_hash(hash)
    return hash unless hash.is_a?(Hash)
    hash = hash.reject{|k,v| diff_skip_fields.include?(k.intern)}
    hash.each do |k,v|
      if v.is_a?(Array)
        hash[k] = v.map{|a| clean_hash(a)}
      elsif v.is_a?(Hash)
        hash[k] = clean_hash(v)
      end
    end
    hash
  end


  def self.digest_json(json_hash)
    Digest::SHA1.hexdigest(ASUtils.to_json(clean_hash(json_hash)))
  end


  def self.ensure_current_versions(objs, jsons)
    return if objs.empty?

    latest_versions = db[:history]
      .left_join(Sequel.as(:history, :b), {:history__record_id => :b__record_id,  :history__model => :b__model}) {|j,lj,js|
         Sequel.qualify(lj, :lock_version) < Sequel.qualify(j, :lock_version)
       }
      .filter(:b__lock_version => nil)
      .filter(:history__model => objs.first.class.table_name.to_s)
      .filter(:history__record_id => objs.map{|o| o.id})
      .select_hash(:history__record_id, [:history__lock_version, :history__digest, :history__revision])

    jsons.zip(objs).each do |json, obj|
      json_hash = json.to_hash(:trusted)
      digest = digest_json(json_hash)

      if !latest_versions[obj.id] || (latest_versions[obj.id][0] < obj.lock_version && latest_versions[obj.id][1] != digest)
        hist = {
          :record_id => obj.id,
          :model => obj.class.table_name.to_s,
          :revision => latest_versions.fetch(obj.id, [0,0,0])[2] + 1,
          :lock_version => obj.lock_version,
          :repo_id => obj.respond_to?(:repo_id) ? obj.repo_id : 0,
          :uri => json[:uri],
          :label => label_for(json),
          :suppressed => json[:suppressed] ? 1 : 0,
          :created_by => map_field(obj, :created_by),
          :last_modified_by => map_field(obj, :last_modified_by),
          :create_time => map_field(obj, :create_time),
          :system_mtime => map_field(obj, :system_mtime),
          :user_mtime => map_field(obj, :user_mtime),
          :digest => digest,
          :json => Sequel::SQL::Blob.new(Zlib::Deflate.deflate(ASUtils.to_json(json_hash))),
        }

        handle_insert(hist)
      end
    end
  end


  def self.map_field(obj, field)
    val = model_map[obj.class].has_key?(field) ? model_map[obj.class][field] : field
    
    if val.is_a?(Proc)
      val.call(obj)
    else
      obj.send(val)
    end
  end


  def self.record_delete(obj)
    uri_hash = obj.respond_to?(:repo_id) ? {:repo_id => obj.repo_id} : {}

    # deletion does not respect lock_version, so we can't trust `obj`
    # to have the current lock_version. so we ask history to just
    # give us the latest version
    latest_version = History.new(obj.class.table_name.to_s, obj.id).version
    label = label_for(latest_version.json)
    json = {:deleted => true}

    hist = {
      :record_id => obj.id,
      :model => obj.class.table_name.to_s,
      :revision => latest_version.version + 1,
      :lock_version => latest_version.lock_version + 1,
      :repo_id => obj.respond_to?(:repo_id) ? obj.repo_id : 0,
      :uri => obj.class.my_jsonmodel(true).uri_for(obj.id, uri_hash),
      :label => label,
      :suppressed => obj.respond_to?(:suppressed) ? obj.suppressed : 0,
      :created_by => obj.created_by,
      :last_modified_by => obj.last_modified_by,
      :create_time => obj.create_time,
      :system_mtime => obj.system_mtime,
      :user_mtime => Time.now,
      :digest => digest_json(json),
      :json => Sequel::SQL::Blob.new(Zlib::Deflate.deflate(ASUtils.to_json(json))),
    }

    handle_insert(hist)
  end


  def self.handle_suppression(model, ids, val)
    if models.include?(model)
      db[:history].filter(:model => model.table_name.to_s)
        .filter(:record_id => ids)
        .update(:suppressed => val ? 1 : 0)
    end
  end


  def self.update_status(hist)
    return if SystemStatus.ancestors.include?(SystemStatusDisabled)

    @stat_counter ||= StatCounter.new(60)

    SystemStatus.update('Last History Update', :good,
                        "#{hist[:model]} / #{hist[:record_id]} .v#{hist[:revision]} by #{hist[:last_modified_by]} -- #{hist[:label]}")

    unless @stat_counter.add
      SystemStatus.update('History Updates', 60 * @stat_counter.count / @stat_counter.sample_time < 10  ? :good : :busy,
                          "#{@stat_counter.count} updates in the last #{@stat_counter.sample_time}s")

      @stat_counter.reset
    end
  end


  def self.uri_for(obj, version = nil)
    uri(obj.class.table_name.to_s, obj.id, version)
  end


  def self.label_for(json)
    label = json['name'] || json['display_string'] || json['title'] || 'NO LABEL'
    label.strip.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').slice(0, 255)
  end


  def self.uri(model, id, version = nil)
    ['/history', model, id, version].compact.join('/')
  end


  def self.uri_for_uri_at(time, uri)
    version = db[:history].filter(:uri => uri).where{user_mtime <= time}.reverse(:revision).first
    version ? uri(version[:model], version[:record_id], version[:revision]) : uri
  end


  def self.apply_scope(dataset, filters)
    ds = dataset
    if filters.has_key?(:scope)
      ds = ds.where{{:suppressed => 0} | {1 => filters[:scope][:view_suppressed]} | {:repo_id => filters[:scope][:view_suppressed]}}
      ds = ds.where{{:repo_id => 0} | {1 => filters[:scope][:view_repository]} | {:repo_id => filters[:scope][:view_repository]}}
    end
    ds
  end


  def self.apply_filters(dataset, filters)
    ds = apply_scope(dataset, filters)
    ds = ds.limit(filters.fetch(:limit, 10)) if filters.has_key?(:limit)
    ds = ds.filter(:model => filters[:model]) if filters.has_key?(:model)
    ds = ds.filter(:last_modified_by => filters[:user]) if filters.has_key?(:user)

    if filters.has_key?(:time)
      time = normalize_time(filters[:time])
      ds = ds.where{user_mtime <= time}
    end

    ds = ds.where{revision <= filters[:version]} if filters.has_key?(:version)
    ds
  end


  def self.normalize_time(time)
    @date_time_mask ||= '9999-12-31 23:59:59'
    Time.new(*(time + @date_time_mask[time.length .. -1]).split(/[^\d]/)).utc
  end


  def self.localize_times(fields, hash)
    hash.map{|k,v| [k, fields.include?(k) ? v.getlocal.strftime("%F %T") : v] }.to_h
  end


  def self.versions(model, id, filters = {})
    if model && id
      History.new(model, id, filters[:scope]).versions(filters)
    elsif model
      History.latest(filters.merge(:model => model))
    else
      History.latest(filters)
    end
  end


  def self.latest(filters = {})
    ds = History.apply_filters(db[:history], filters)
      .reverse(:user_mtime)
      .select(*fields.reject{|f| f == :json})

    raise VersionNotFound.new if ds.empty?

    Hash[ds.all.map{|r| [History.uri(r[:model], r[:record_id], r[:revision]), Version.from_row(r)]}]
  end


  def self.version(model, id, version)
    History.new(model, id).version(version)
  end


  def self.diff(model, id, a, b, scope = false)
    History.new(model, id, scope).diff(a, b)
  end


  def self.restore_version!(model, record_id, version_id)
    record_model = ASModel.all_models.select {|m| m.table_name == model.intern}.first
    json = JSONModel::JSONModel(model.intern).from_hash(History.version(model, record_id, version_id).json(false), true, :trusted)

    reference = JSONModel.parse_reference(json.uri)

    if reference[:repository]
      repo_id = JSONModel.parse_reference(reference[:repository])[:id]
      RequestContext.open(:repo_id => repo_id) do
        _handle_restore(record_model, record_id, json)
      end
    else
      _handle_restore(record_model, record_id, json)
    end
  end


  def self._lock_versions_for_uris!(json)
    return unless json.respond_to?(:data) || json.is_a?(Hash)

    if json.has_key?('uri') && json.has_key?('lock_version')
      ref = JSONModel.parse_reference(json['uri'])
      if ref && ref[:type] == json['jsonmodel_type']
        json['lock_version'] = db[ref[:type].intern].filter(:id => ref[:id]).get(:lock_version)
      end
    end

    (json.is_a?(Hash) ? json : json.data).each do |k,v|
      if v.is_a?(Hash)
        _lock_versions_for_uris!(v)
      elsif v.is_a?(Array)
        v.each do |h|
          _lock_versions_for_uris!(h)
        end
      end
    end

    json
  end


  def self._handle_restore(model, id, json)
    begin
      obj = model.get_or_die(id)
      obj.update_from_json(_lock_versions_for_uris!(json))
    rescue NotFoundException
      # a restoring deleted record
      obj = model.create_from_json(json, {:lock_version => json.lock_version + 2})

      # bring the previous incarnation's history along with us
      db[:history].filter(:model => model.table_name.to_s, :record_id => id).update(:record_id => obj.id)

      # this retains the old id, but at what cost?!
#       begin
#         restricted_model = model.restrict_primary_key?
#         model.unrestrict_primary_key if restricted_model
#         obj = model.create_from_json(json, {:id => id, :lock_version => json.lock_version + 1})
#         [obj, json]
#       ensure
#         model.restrict_primary_key if restricted_model
#       end

      # remove the record's tombstone
      Tombstone.filter(:uri => json[:uri]).delete
    end

    [obj, json]
  end


  attr_reader :ds, :model, :id

  def initialize(model, id, scope = false)
    @model = model
    @id = id
    @ds = db[:history].filter(:model => @model, :record_id => @id)
    @ds = History.apply_scope(@ds, {:scope => scope}) if scope
    raise VersionNotFound.new if @ds.empty?
  end


  def versions(filters = {})
    my_ds = History.apply_filters(ds, filters)
                   .reverse(:revision)
                   .select(*History.fields.reject{|f| f == :json})

    raise VersionNotFound.new if my_ds.empty?

    Hash[my_ds.all.map {|r| [History.uri(r[:model], r[:record_id], r[:revision]), Version.from_row(r)]}]
  end


  def version(version = nil)
    Version.new(self, version)
  end


  def diff(a, b, convert_uris = false)
    diffs = {:_changes => {}, :_adds => {}, :_removes => {}}
    return diffs if a == b

    (from_json, to_json) = diff_versions_json(a, b, convert_uris)
    return diffs unless from_json && to_json

    (to_json.keys - from_json.keys).each{|k| diffs[:_adds][k] = to_json[k]}
    (from_json.keys - to_json.keys).each{|k| diffs[:_removes][k] = from_json[k]}

    (to_json.keys & from_json.keys).each do |k|
      next if History.diff_skip_fields.include?(k.intern)
      next if from_json[k] == to_json[k]

      if from_json[k].is_a? Array
        ca = []
        fa = from_json[k] + (Array.new([to_json[k].length - from_json[k].length, 0].max))
        fa.zip(to_json[k]) do |f, t|
          if f && t
            hd = _nested_hash_diff(f,t)
            ca.push(hd)
          else
            ca.push({:_from => f, :_to => t})
          end
        end
        diffs[:_changes][k] = ca if ca.any?{|h| !h.empty?}
      elsif to_json[k].is_a? Hash
        hd = _nested_hash_diff(from_json[k], to_json[k])
        diffs[:_changes][k] = hd unless hd.empty?
      else
        diffs[:_changes][k] = {:_from => from_json[k], :_to => to_json[k]}
      end
    end

    diffs    
  end


  def diff_versions_json(a, b, convert_uris = true)
    begin
      from_json = version([a,b].min).json(convert_uris)
    rescue VersionNotFound
      # too bad, but there might be a to_json, so ...
    end

    return [from_json, nil] if from_json && a == b

    begin
      to_json = version([a,b].max).json(convert_uris)
    rescue VersionNotFound => e
      # ok so we tried, but if neither version exists, then ...
      raise e unless from_json
    end

    [from_json, to_json]
  end


  def inline_diff(a, b, convert_uris = true)
    (from_json, to_json) = diff_versions_json(a, b, convert_uris)

    if from_json && to_json
      inline_hash_diff(from_json, to_json)
    else
      [from_json, to_json].compact.first
    end
  end


  private

  def self.handle_insert(hist)
    begin
      self.insert(hist)

      update_status(hist)

    rescue Sequel::UniqueConstraintViolation
      # Someone beat us to it. No worries!
    end

  end


  def without_audit(hash)
    return hash unless hash.is_a?(Hash)
    hash.select{|k,v| !History.diff_skip_fields.include?(k.intern)}
  end


  def inline_hash_diff(a, b)
    out = {}
    zip_align(without_audit(a).keys, without_audit(b).keys).each do |a_key, b_key|
      the_key = a_key || b_key

      if a_key && b_key
        if a[a_key].is_a? Hash
          out[a_key] = inline_hash_diff(a[a_key], b[b_key])
        elsif a[a_key].is_a? Array
          aa = a[a_key] + (Array.new([b[b_key].length - a[a_key].length, 0].max))
          aa.zip(b[b_key]).each do |av, bv|
            out[a_key] ||= []
            if av && bv
              if av.is_a? Hash
                out[a_key].push(inline_hash_diff(av, bv))
              else
                if compare(av, bv)
                  out[a_key].push(av)
                else
                  out[a_key].push({'_diff' => [av, bv]})
                end
              end
            elsif av
              out[a_key].push({'_diff' => [without_audit(av), nil]})
            else
              out[a_key].push({'_diff' => [nil, without_audit(bv)]})
            end
          end
        else
          if compare(a[a_key], b[b_key])
            out[b_key] = b[b_key]
          else
            out[a_key] = {'_diff' => [a[a_key], b[b_key]]}
          end
        end
      elsif a_key
        out[a_key] = {'_diff' => [without_audit(a[a_key]), nil]}
      else
        out[b_key] = {'_diff' => [nil, without_audit(b[b_key])]}
      end
    end

    out
  end


  def compare(a, b)
    # don't be foxed by converted uris
    a = a.sub(/\/\d+$/, '') if a.is_a?(String) && a.start_with?('/history/')
    b = b.sub(/\/\d+$/, '') if b.is_a?(String) && b.start_with?('/history/')
    a == b
  end


  def zip_align(a, b)
    out = []
    ax = bx = 0

    (a & b).each do |sv|
      (ax..a.index(sv)-1).each do |ix|
        out.push([a[ix], nil])
        ax += 1
      end

      (bx..b.index(sv)-1).each do |ix|
        out.push([nil, b[ix]])
        bx += 1
      end

      out.push([sv,sv])
      ax += 1
      bx += 1
    end

    (ax..a.length-1).each do |ix|
      out.push([a[ix], nil])
      ax += 1
    end

    (bx..b.length-1).each do |ix|
      out.push([nil, b[ix]])
      bx += 1
    end

    out
  end


  def _nested_hash_diff(from, to)
    out = {}
    (from.keys | to.keys).each do |k|
      next if History.diff_skip_fields.include?(k.intern)
      if from[k].is_a? Hash
        hd = _nested_hash_diff(from[k], to[k])
        out[k] = hd unless hd.empty?
        next
      end
      next if compare(from[k], to[k])
      out[k] = {:_from => from[k], :_to => to[k]}
    end
    out
  end


  ###


  class Version

    def self.from_row(row)
      # localize the datetime fields
      data = History.localize_times(History.datetime_fields, row)

      # derive a short form of the label
      data[:short_label] = 
        if data[:label].length > 30
          data[:label].slice(0, 17) + '...' + data[:label].slice(-10, 10)
        else
          data[:label]
        end

      data[:system_version] = (History.system_version_at(data[:user_mtime])[:label] rescue History::VersionNotFound && '[UNKNOWN]')

      data
    end


    def initialize(history, vers = nil)
      @history = history
      if vers.is_a?(Integer)
        @data = _version_or_die(@history.ds.filter(:revision => vers))
      elsif vers.is_a?(String)
        @time = n_time = History.normalize_time(vers)
        @data = _version_or_die(@history.ds.where{user_mtime <= n_time}.reverse(:revision))
      else
        @data = _version_or_die(@history.ds.reverse(:revision))
      end
    end


    def data
      {History.uri(@data[:model], @data[:record_id], @data[:revision]) => @data.reject{|f| f == :json}}
    end


    def version
      @data[:revision]
    end

    def lock_version
      @data[:lock_version]
    end

    def time
      @data[:user_mtime]
    end

    def uri
      @data[:uri]
    end

    def json(convert_uris = true)
      ASUtils.json_parse(convert_uris ? _convert_uris(_inflated_json) : _inflated_json)
    end


    private

    def _version_or_die(ds)
      Version.from_row(ds.first || raise(History::VersionNotFound.new))
    end


    def _inflated_json
      Zlib::Inflate.inflate(Sequel::SQL::Blob.new(@data[:json]))
    end


    def _convert_uris(json)
      time = @time || @data[:user_mtime]
      json.gsub(/\"((\/[^\/ \"]+)+)/) {|m| '"' + History.uri_for_uri_at(time, $1)}
    end

  end


  class SystemVersion < Sequel::Model(:history_system_version)

    def self.from_row(row)
      # localize first_seen
      hash = History.localize_times([:first_seen], row)

      # parse config
      if hash[:config]
        hash[:config] = ASUtils.json_parse(hash[:config])
      else
        hash.delete(:config)
      end

      # label
      hash[:label] = "#{hash[:version]} [#{hash[:config_digest][0..6]}]"

      hash
    end


    def self.fields
      @fields ||=
        [
         :version,
         :config_digest,
         :first_seen,
         :config,
        ]
    end


    attr_reader :data

    def initialize(time = false)
      ds = db[:history_system_version].reverse(:first_seen)
      ds = ds.where{first_seen <= time} if time
      raise(History::VersionNotFound.new) unless ds.first

      @data = SystemVersion.from_row(ds.first)
    end
  end
end
