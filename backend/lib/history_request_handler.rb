class HistoryRequestHandler

  attr_accessor :mode, :user, :time, :convert_uris, :diff, :limit, :admin, :permissions, :only_repos

  def initialize(current_user, opts = {})
    self.mode =         opts[:mode]  # what data to show
    self.user =         opts[:user]  # only include versions by user
    self.time =         opts[:at]    # only include versions at or before time
    self.convert_uris = opts[:uris]  # convert uris to history equivalents
    self.diff =         opts[:diff]  # the version to diff against
    self.limit =        opts[:limit] # limit the number of versions to show

    self.admin = current_user.can?(:administer_system)
    self.permissions = current_user.permissions

    unless admin
      self.only_repos = current_user.permissions.select{|k,v| v.include?('view_repository')}.keys.map{|uri| uri.split('/')[-1].to_i}
#      self.view_supp = current_user.permissions.select{|k,v| v.include?('view_suppressed')}.keys.map{|uri| uri.split('/')[-1].to_i}
    end
  end


  def get_history(model = false, id = false, version = false)
    filters = {}
    filters[:user] = user if user
    filters[:time] = time if time
    filters[:limit] = limit if limit
    filters[:version] = version if version

    (history, version, list) =
      if model && id
        history = History.new(model, id, only_repos)
        [
         history,
         history.version(version || time),
         history.versions(filters.reject{|k,v| mode.match(/^f/) && k == :version})
        ]
      else
        filters[:mode] = 'list'
        filters[:only_repos] = only_repos if only_repos
        versions = History.versions(model, id, filters)
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


  def diff(model, id, a, b)
    History.diff(model, id, a, b, only_repos)
  end


  def restore_version!(model, id, version)
    # Make sure the user is allowed to update this record
    unless admin
      record_uri = History.new(model, id, only_repos).version(version).uri
      restore_perms = ArchivesSpaceService::Endpoint.permissions_for(:post, record_uri).map(&:to_s)
      perm_key = if (uri_match = record_uri.match(/^\/repositories\/\d+/))
                   uri_match[0]
                 else
                   '_archivesspace'
                 end

      raise AccessDeniedException.new("Access denied") if ((permissions[perm_key] || []) & restore_perms).empty?
    end

    (obj, json) = History.restore_version!(model, id, version)

    RequestContext.open(:repo_id => obj.respond_to?(:repo_id) ? obj.repo_id : nil) do
      {:status => 'Restored', :uri => obj.uri}
    end
  end

end
