models_with_history =
  [
   Repository,
   Resource,
   ArchivalObject,
   DigitalObject,
   DigitalObjectComponent,
   Accession,
   AgentPerson,
   AgentCorporateEntity,
   AgentFamily,
   AgentSoftware,
  ]

models_with_history.map {|model| model.prepend(Auditable) }
