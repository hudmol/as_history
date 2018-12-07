class HistoryRequestHandler

  attr_accessor :mode, :user, :time, :convert_uris, :diff, :limit

  def initialize(opts = {})
    self.mode =         opts[:mode]  # what data to show
    self.user =         opts[:user]  # only include versions by user
    self.time =         opts[:at]    # only include versions at or before time
    self.convert_uris = opts[:uris]  # convert uris to history equivalents
    self.diff =         opts[:diff]  # the version to diff against
    self.limit =        opts[:limit] # limit the number of versions to show
  end


  def get_history(model = false, id = false, version = false)
    filters = {}
    filters[:user] = user if user
    filters[:time] = time if time
    filters[:limit] = limit if limit
    filters[:version] = version if version

    (history, version, list) =
      if model && id
        history = History.new(model, id)
        [
         history,
         history.version(version || time || Time.now),
         history.versions(filters.reject{|k,v| mode.match(/^f/) && k == :version})
        ]
      else
        versions = History.versions(model, id, filters.merge(:mode => 'list'))
        latest = versions.values.first
        history = History.new(latest[:model], latest[:record_id])
        [
         history,
         history.version(latest[:lock_version]),
         versions
        ]
      end

    case mode
    when nil || /^l/ # list
      list

    when /^j/ # json
      version.json(convert_uris)

    when /^d/ # data
      version.data

    when /^f/ # full
      {
        :data => version.data,
        :json => version.json(convert_uris),
        :diff => (history.diff(version.version, diff || version.version - 1) rescue History::VersionNotFound && nil),
        :versions => list,
      }

    end
  end

end
