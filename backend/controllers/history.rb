class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/history/models')
  .description("Get a list of models that support history")
  .params()
  .permissions([])
  .returns([200, "(models)"]) \
  do
    json_response(History.models)
  end


  Endpoint.get('/history')
  .description("Get recently created versions")
  .params(["user", String, "Only show recent versions by user", :optional => true],
          ["limit", Integer, "How many to show", :default => 10],
          ["mode", String, "What data to return - list, json, data, full", :default => 'list'],
          ["uris", BooleanParam, "Convert uris to historical equivalents", :default => true])
  .permissions([:view_all_records])
  .returns([200, "versions"]) \
  do
    handler = HistoryRequestHandler.new(params)

    begin
      json_response(handler.get_history)
    rescue History::VersionNotFound => e
      json_response({:error => e}, 404)
    end
  end


  Endpoint.get('/history/:model')
  .description("Get versions of records of the model")
  .params(["model", String, "The model"],
          ["limit", Integer, "How many to show", :default => 10],
          ["user", String, "Only show versions by user", :optional => true],
          ["at", String, "Return the versions created at or before the specified date/time", :optional => true],
          ["mode", String, "What data to return - list, json, data, full", :default => 'list'],
          ["uris", BooleanParam, "Convert uris to historical equivalents", :default => true])
  .permissions([:view_all_records])
  .returns([200, "history"]) \
  do
    handler = HistoryRequestHandler.new(params)

    begin
      json_response(handler.get_history(params[:model]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 404)
    end
  end


  Endpoint.get('/history/:model/:id')
  .description("Get version history for the record")
  .params(["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["user", String, "Only show versions by user", :optional => true],
          ["at", String, "Return the version current at the specified date/time", :optional => true],
          ["mode", String, "What data to return - list, json, data, full", :default => 'list'],
          ["uris", BooleanParam, "Convert uris to historical equivalents", :default => true])
  .permissions([:view_all_records])
  .returns([200, "history"]) \
  do
    handler = HistoryRequestHandler.new(params)

    begin
      json_response(handler.get_history(params[:model], params[:id]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 404)
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
    handler = HistoryRequestHandler.new(params)

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
  .permissions([:administer_system])
  .returns([200, "version"]) \
  do
    begin
      (obj, json) = History.restore_version!(params[:model], params[:id], params[:version])

      RequestContext.open(:repo_id => obj.respond_to?(:repo_id) ? obj.repo_id : nil) do
        json_response({:status => 'Restored', :uri => obj.uri})
      end
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
  .permissions([:view_all_records])
  .returns([200, "version diff"]) \
  do
    begin
      json_response(History.diff(params[:model], params[:id], params[:a], params[:b]))
    rescue History::VersionNotFound => e
      json_response({:error => e}, 404)
    end
  end

end
