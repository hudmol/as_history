class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/history')
  .description("Get recently created versions")
  .params(["user", String, "Only show recent versions by user", :optional => true],
          ["limit", Integer, "How many to show", :default => 10],
          ["mode", String, "What data to return - json (default), data, full", :default => 'json'],
          ["uris", BooleanParam, "Convert uris to historical equivalents", :default => true])
  .permissions([:view_all_records])
  .returns([200, "versions"]) \
  do
    if params[:user]
        json_response(get_latest_version(History.recent_for_user(params[:user], params[:limit]), params[:mode], params[:uris]))
      else
        json_response(get_latest_version(History.recent(params[:limit]), params[:mode], params[:uris]))
      end
  end


  Endpoint.get('/history/:model/:id')
  .description("Get version history for the record")
  .params(["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["at", String, "Return the version current at the specified date/time", :optional => true],
          ["mode", String, "What data to return - json (default), data, full", :default => 'json'],
          ["uris", BooleanParam, "Convert uris to historical equivalents", :default => true])
  .permissions([:view_all_records])
  .returns([200, "history"]) \
  do
    begin
      if params[:at]
        json_response(get_version(params[:model], params[:id], params[:at], params[:mode], params[:uris]))
      else
        if params[:mode].start_with?('f')
          json_response(get_version(params[:model], params[:id], Time.now, params[:mode], params[:uris]))
        else
          json_response(History.versions(params[:model], params[:id]))
        end
      end
    rescue History::VersionNotFound => e
      json_response({:error => e}, 400)
    end
  end


  Endpoint.get('/history/:model/:id/:version')
  .description("Get a version of the record")
  .params(["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["version", Integer, "The version"],
          ["mode", String, "What data to return - json (default), data, full", :default => 'json'],
          ["diff", Integer, "The version to diff from in full mode", :optional => true],
          ["uris", BooleanParam, "Convert uris to historical equivalents", :default => true])
  .permissions([:view_all_records])
  .returns([200, "version"]) \
  do
    begin
      json_response(get_version(params[:model], params[:id], params[:version], params[:mode], params[:uris], params[:diff]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 400)
    end
  end


  Endpoint.post('/history/:model/:id/:version/restore')
  .description("Restore a version of the record")
  .params(["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["version", Integer, "The version to restore"])
  .permissions([:administer_system])
  .returns([200, "version"]) \
  do
    begin
      record_model = ASModel.all_models.select {|m| m.table_name == params[:model].intern}.first
      json = JSONModel(params[:model].intern).from_hash(get_version(params[:model], params[:id], params[:version], 'json', false))
      json.lock_version = get_version(params[:model], params[:id], Time.now, 'data', false).values.first[:lock_version]

      # dealing with repo scoping ... HELPME
      repo_match = json.uri.match(/^\/repositories\/(\d+)/)
      if repo_match
        RequestContext.open(:repo_id => repo_match[1]) do
          params[:repo_id] = repo_match[1]
          obj = record_model.get_or_die(params[:id])
          obj.update_from_json(json, :repo_id => repo_match[1])
          updated_response(obj, json)
        end
      else
        obj = record_model.get_or_die(params[:id])
        obj.update_from_json(json)
        updated_response(obj, json)
      end
    rescue History::VersionNotFound => e
      json_response({:error => e}, 400)
    end
  end


  Endpoint.get('/history/:model/:id/:a/:b')
  .description("Get a diff between versions of the record")
  .params(["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["a", Integer, "The 'a' version"],
          ["b", Integer, "The 'b' version"])
  .permissions([:view_all_records])
  .returns([200, "version diff"]) \
  do
    begin
      json_response(History.diff(params[:model], params[:id], params[:a], params[:b]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 400)
    end
  end


  Endpoint.get('/history/models')
  .description("Get a list of models that support history")
  .params()
  .permissions([])
  .returns([200, "(models)"]) \
  do
    json_response(History.models)
  end


  def get_version(model, id, version_or_time, mode, uris, diff = nil)
    history = History.new(model, id)
    version = history.version(version_or_time)
    diff_version = diff || version.version - 1
    if mode.start_with?('f')
      {
        :json => version.json(uris),
        :data => version.data,
        :diff => (history.diff(version.version, diff_version) rescue History::VersionNotFound && nil),
        :versions => history.versions,
      }
    elsif mode.start_with?('d')
      version.data
    else
      version.json(uris)
    end
  end


  def get_latest_version(versions, mode, uris)
    latest = versions.values.first
    history = History.new(latest[:model], latest[:record_id])
    version = history.version(latest[:lock_version])
    if mode.start_with?('f')
      {
        :json => version.json(uris),
        :data => version.data,
        :diff => (history.diff(version.version, version.version - 1) rescue History::VersionNotFound && nil),
        :versions => versions,
      }
    elsif mode.start_with?('d')
      version.data
    else
      version.json(uris)
    end
  end

end
