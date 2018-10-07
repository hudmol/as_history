class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/history/:model/:id')
  .description("Get version history for the record")
  .params(["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["at", String, "Return the version current at the specified date/time", :optional => true])
  .permissions([])
  .returns([200, "history"]) \
  do
    if params[:at]
      json_response(History.version_at(params[:model], params[:id], params[:at]))
    else
      json_response(History.versions(params[:model], params[:id]))
    end
  end


  Endpoint.get('/history/:model/:id/:version')
  .description("Get version history for the record")
  .params(["model", String, "The model"],
          ["id", Integer, "The ID"],
          ["version", Integer, "The version"])
  .permissions([])
  .returns([200, "version"]) \
  do
    json_response(History.version(params[:model], params[:id], params[:version]))
  end

end
