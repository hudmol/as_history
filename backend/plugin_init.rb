require_relative 'lib/history_resolver.rb'
require_relative 'lib/history_formatter.rb'

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

