module Auditable

  def self.prepended(base)
    class << base
      prepend(ClassMethods)
    end
  end


  def delete
    super
    History.record_delete(self)
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
