class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/history/:model/:id')
  .description("Get version history for the record")
  .params(["model", String, "The model"],
          ["id", Integer, "The ID"])
  .permissions([])
  .returns([200, "history"]) \
  do
    json_response(History.versions(params[:model], params[:id]))
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
