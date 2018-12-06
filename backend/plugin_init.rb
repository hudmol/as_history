require_relative 'lib/history_resolver.rb'
require_relative 'lib/history_request_handler.rb'

[
 Repository,
 Accession,
 Resource,
 ArchivalObject,
 DigitalObject,
 DigitalObjectComponent,
 Assessment,
 Classification,
 CollectionManagement,
 ContainerProfile,

 AgentPerson,
 AgentCorporateEntity,
 AgentFamily,
 AgentSoftware,
 Location,
 Subject,
 TopContainer,
 Vocabulary,
].each do |model|

  History.register_model(model)

end

# Load custom schema
JSONModel::JSONModel(:history)

URIResolver.register_resolver(HistoryResolver)


# wiring for asam
begin
  StatCounter
  SystemStatus.group('History', ['History Updates', 'Last History Update'])
  SystemStatus.update('History Updates', :no, 'History enabled. Waiting for updates ...')
  SystemStatus.update('Last History Update', :no, 'History enabled. Waiting for updates ...')
rescue => e
  Log.info "Install asam to enable history monitoring"
  Log.debug "History asam fail: " + e.message

  # asam isn't active so fake SystemStatus and StatCounter
  class SystemStatus
    def self.method_missing(meth, *args)
      Log.debug("asam not active, so ignoring: SystemStatus: ##{meth}(#{args.join(', ')})")
    end
  end

  class StatCounter
    def self.method_missing(meth, *args)
      Log.debug("asam not active, so ignoring: StatCounter: ##{meth}(#{args.join(', ')})")
    end
  end
end
