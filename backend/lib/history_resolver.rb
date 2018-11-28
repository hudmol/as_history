class HistoryResolver < URIResolver::ResolverType
  def self.handler_for(jsonmodel_type)
    if jsonmodel_type == 'history'
      # it's-a me!
      new
    end
  end

  def resolve(uris)
    Enumerator.new do |yielder|
      uris.each do |uri|
        (model, id) = parse_history_uri(uri, nil)
        if model && id
          versions = History.versions(model, Integer(id))
          yielder << [
            uri,
            versions.map {|version_uri, values|
              [version_uri, ASUtils.keys_as_strings(values)]
            }.to_h
          ]
        end
      end
    end
  end

  def record_exists?(uri)
    begin
      id = Integer(uri.split('/')[-1])
      History.exist?(id)
      true
    rescue
      false
    end
  end

  private

  # Return [model, id] for a given URI, or fail_value if the parse fails.
  def parse_history_uri(uri, fail_value)
    uri.scan(%r{\A/history/(.*?)/([0-9]+)\z})[0] or fail_value
  end

end
