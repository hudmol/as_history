ArchivesSpace::Application.extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))

ArchivesSpace::Application.config.after_initialize do
  MemoryLeak::Resources.define(:history_models, proc { JSONModel::HTTP.get_json('/history/models') }, 60)
end
