class HistoryFormatter

  def get_version(model, id, version_or_time, mode, uris, diff = nil)
    history = History.new(model, id)
    version = history.version(version_or_time)
    diff_version = diff || version.version - 1
    if mode.start_with?('f')
      {
        :json => version.json(uris),
        :data => version.data,
        :diff => (history.diff(version.version, diff_version) rescue History::VersionNotFound && nil),
        :versions => history.versions,
      }
    elsif mode.start_with?('d')
      version.data
    else
      version.json(uris)
    end
  end


  def get_latest_version(versions, mode, uris)
    raise History::VersionNotFound.new if versions.empty?

    latest = versions.values.first
    history = History.new(latest[:model], latest[:record_id])
    version = history.version(latest[:lock_version])
    if mode.start_with?('f')
      {
        :json => version.json(uris),
        :data => version.data,
        :diff => (history.diff(version.version, version.version - 1) rescue History::VersionNotFound && nil),
        :versions => versions,
      }
    elsif mode.start_with?('d')
      version.data
    else
      version.json(uris)
    end
  end

end
