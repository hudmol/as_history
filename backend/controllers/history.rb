class ArchivesSpaceService < Sinatra::Base

  COMMON_PARAMS =
    [
     ["user",  String,       "Only show updates by user", :optional => true],
     ["at",    String,       "Only show updates at or before the specified date/time", :optional => true],
     ["uris",  BooleanParam, "Convert uris to historical equivalents", :default => true],
    ]

  Endpoint.get('/history/models')
  .description("Get a list of models that support history")
  .params()
  .permissions([])
  .returns([200, "(models)"]) \
  do
    json_response(History.models)
  end


  Endpoint.get('/history/system_versions')
  .description("Get a list of system versions")
  .params()
  .permissions([:administer_system])
  .returns([200, "(system versions)"]) \
  do
    json_response(History.system_versions)
  end


  Endpoint.get('/history/system_version')
  .description("Get a list of system versions")
  .params(["at", String, "Only show updates at or before the specified date/time", :optional => true])
  .permissions([:administer_system])
  .returns([200, "(system version)"]) \
  do
    json_response(History.system_version_at(params[:at]))
  end


  Endpoint.get('/history')
  .description("Get recently created versions")
  .params(*COMMON_PARAMS,
          ["limit", Integer, "How many to show", :default => 10],
          ["mode", String, "What data to return - list, json, data, full", :default => 'list'])
  .permissions([])
  .returns([200, "versions"]) \
  do
    handler = HistoryRequestHandler.new(current_user, params)

    begin
      json_response(handler.get_history)
    rescue History::VersionNotFound => e
      json_response({:error => e}, 404)
    end
  end


  Endpoint.get('/history/:model')
  .description("Get versions of records of the model")
  .params(*COMMON_PARAMS,
          ["model", String, "The model"],
          ["limit", Integer, "How many to show", :default => 10],
          ["mode", String, "What data to return - list, json, data, full", :default => 'list'])
  .permissions([])
  .returns([200, "history"]) \
  do
    handler = HistoryRequestHandler.new(current_user, params)

    begin
      json_response(handler.get_history(params[:model]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 404)
    end
  end


  Endpoint.get('/history/:model/:id')
  .description("Get version history for the record")
  .params(*COMMON_PARAMS,
          ["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["mode", String, "What data to return - list, json, data, full", :default => 'list'],
          ["limit", Integer, "How many to show", :optional => true])
  .permissions([])
  .returns([200, "history"]) \
  do
    handler = HistoryRequestHandler.new(current_user, params)

    begin
      json_response(handler.get_history(params[:model], params[:id]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 404)
    end
  end


  Endpoint.get('/history/:model/:id/:version')
  .description("Get a version of the record")
  .params(*COMMON_PARAMS,
          ["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["version", Integer, "The version"],
          ["mode", String, "What data to return - json (default), data, full", :default => 'json'],
          ["diff", Integer, "The version to diff from in full mode", :optional => true],
          ["limit", Integer, "How many to show", :optional => true])
  .permissions([])
  .returns([200, "version"]) \
  do
    handler = HistoryRequestHandler.new(current_user, params)

    begin
      json_response(handler.get_history(params[:model], params[:id], params[:version]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 404)
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
    handler = HistoryRequestHandler.new(current_user, params)

    begin
      json_response(handler.restore_version!(params[:model], params[:id], params[:version]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 404)
    end
  end


  Endpoint.get('/history/:model/:id/:version/system')
  .description("Get the system version for the record version")
  .params(["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["version", Integer, "The version to show system version for"])
  .permissions([:administer_system])
  .returns([200, "system version"]) \
  do
    begin
      json_response(History.system_version_for(params[:model], params[:id], params[:version]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 404)
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
      json_response({:error => e}, 404)
    end
  end

end
