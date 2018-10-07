module Auditable

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def sequel_to_jsonmodel(objs, opts = {})
      jsons = super

      History.ensure_current_versions(objs, jsons)

      jsons.zip(objs).each do |json, obj|
        json['history'] = { 'ref' => History.uri_for(obj) }
      end

      jsons
    end
  end
end
