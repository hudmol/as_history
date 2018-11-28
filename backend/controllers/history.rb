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
    formatter = HistoryFormatter.new

    if params[:user]
        json_response(formatter.get_latest_version(History.recent_for_user(params[:user], params[:limit]), params[:mode], params[:uris]))
      else
        json_response(formatter.get_latest_version(History.recent(params[:limit]), params[:mode], params[:uris]))
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
    formatter = HistoryFormatter.new

    begin
      if params[:at]
        json_response(formatter.get_version(params[:model], params[:id], params[:at], params[:mode], params[:uris]))
      else
        if params[:mode].start_with?('f')
          json_response(formatter.get_version(params[:model], params[:id], Time.now, params[:mode], params[:uris]))
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
    formatter = HistoryFormatter.new

    begin
      json_response(formatter.get_version(params[:model], params[:id], params[:version], params[:mode], params[:uris], params[:diff]))
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
    formatter = HistoryFormatter.new

    begin
      (obj, json) = History.restore_version!(params[:model], params[:id], params[:version])

      RequestContext.open(:repo_id => obj.respond_to?(:repo_id) ? obj.repo_id : nil) do
        json_response({:status => 'Restored', :uri => obj.uri})
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

end
