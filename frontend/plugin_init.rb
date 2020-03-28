ArchivesSpace::Application.extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))

ArchivesSpace::Application.config.after_initialize do
  MemoryLeak::Resources.define(:history_models, proc { JSONModel::HTTP.get_json('/history/models') }, 60)


  HistoryController.add_enum_handler {|type, field|
    case type
    when 'note'
      '_note_types'
    when 'linked_agent'
      if field == 'relator'
        'linked_agent_archival_record_relators'
      end
    when 'sub_container'
      "container_#{field.start_with?('type') ? 'type' : field}"
    when "dates_of_existence"
      "date_#{field}"
    end
  }

  HistoryController.add_enum_handler {|type, field|
    case field
    when 'language'
      'language_iso639_2'
    when 'level'
      'archival_record_level'
    end
  }
end
