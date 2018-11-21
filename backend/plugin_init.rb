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
