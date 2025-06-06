module Auditable

  def self.prepended(base)
    class << base
      prepend(ClassMethods)
    end
  end


  def delete
    # it is possible that this record is being deleted without
    # having been retrieved first, in which case there might not
    # be a version for the latest state of the record
    # so let's make sure it's there before we delete
    begin
      version = History.new(self.history_model, self.id).version
      raise History::VersionNotFound.new if version.lock_version != self.lock_version
    rescue History::VersionNotFound
      # the version will be created when we get the record
      self.class.to_jsonmodel(self.id)
    end

    super

    History.record_delete(self)
  end


  def set_suppressed(val)
    super

    object_graph = self.object_graph

    object_graph.each do |model, ids_to_change|
      History.handle_suppression(model, ids_to_change, val)
    end

    val
  end


  def history_model
    self.class.history_model
  end


  module ClassMethods
    def sequel_to_jsonmodel(objs, opts = {})
      jsons = super

      jsons.zip(objs).each do |json, obj|
        json['history'] = { 'ref' => History.uri_for(obj) }
      end

      unless RequestContext.active? && (RequestContext.get(:current_username) == User.SEARCH_USERNAME || RequestContext.get(:is_indexer_thread))
        History.ensure_current_versions(objs, jsons)
      end

      jsons
    end


    def history_model
      my_jsonmodel.record_type.to_s
    end
  end
end
