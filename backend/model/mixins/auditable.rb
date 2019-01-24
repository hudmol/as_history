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
      History.new(self.class.table_name.to_s, self.id).version(self.lock_version)
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


  module ClassMethods
    def sequel_to_jsonmodel(objs, opts = {})
      jsons = super

      jsons.zip(objs).each do |json, obj|
        json['history'] = { 'ref' => History.uri_for(obj) }
      end

      History.ensure_current_versions(objs, jsons)

      jsons
    end
  end
end
