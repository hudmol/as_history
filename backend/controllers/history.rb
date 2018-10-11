class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/history')
  .description("Get recently created versions")
  .params(["limit", Integer, "How many to show (default 10)", :default => 10])
  .permissions([])
  .returns([200, "versions"]) \
  do
    json_response(History.recent(params[:limit]))
  end


  Endpoint.get('/history/:model/:id')
  .description("Get version history for the record")
  .params(["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["at", String, "Return the version current at the specified date/time", :optional => true],
          ["mode", String, "What data to return - json (default), data, full", :default => 'json'],
          ["uris", BooleanParam, "Convert uris to historical equivalents", :default => true])
  .permissions([])
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
          ["uris", BooleanParam, "Convert uris to historical equivalents", :default => true])
  .permissions([])
  .returns([200, "version"]) \
  do
    begin
      json_response(get_version(params[:model], params[:id], params[:version], params[:mode], params[:uris]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 400)
    end
  end


  Endpoint.post('/history/:model/:id/:version/restore')
  .description("Restore a version of the record")
  .params(["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["version", Integer, "The version to restore"])
  .permissions([])
  .returns([200, "version"]) \
  do
    begin
      record_model = ASModel.all_models.select {|m| m.table_name == params[:model].intern}.first
      obj = record_model.get_or_die(params[:id])
      json = JSONModel(params[:model].intern).from_hash(get_version(params[:model], params[:id], params[:version], 'json', false))
      json.lock_version = get_version(params[:model], params[:id], Time.now, 'data', false).values.first[:lock_version]
      obj.update_from_json(json)
      updated_response(obj, json)
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
  .permissions([])
  .returns([200, "version diff"]) \
  do
    begin
      json_response(History.diff(params[:model], params[:id], params[:a], params[:b]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 400)
    end
  end


  def get_version(model, id, version_or_time, mode, uris)
    history = History.new(model, id)
    version = history.version(version_or_time)
    if mode.start_with?('f')
      {
        :json => version.json(uris),
        :data => version.data,
        :diff => (history.diff(version.time, version.time - 1) rescue History::VersionNotFound && nil),
        :versions => history.versions,
      }
    elsif mode.start_with?('d')
      version.data
    else
      version.json(params[:uris])
    end
  end
end
