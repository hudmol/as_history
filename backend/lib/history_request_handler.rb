class HistoryRequestHandler

  attr_accessor :mode, :user, :time, :convert_uris, :diff, :limit, :admin, :permissions, :scope

  def initialize(current_user, opts = {})
    self.mode =         opts[:mode]  # what data to show
    self.user =         opts[:user]  # only include versions by user
    self.time =         opts[:at]    # only include versions at or before time
    self.convert_uris = opts[:uris]  # convert uris to history equivalents
    self.diff =         opts[:diff]  # the version to diff against
    self.limit =        opts[:limit] # limit the number of versions to show

    self.admin = current_user.can?(:administer_system)
    # the anonymous user, strangely, doesn't respond to permissions
    self.permissions = current_user.respond_to?(:permissions) ? current_user.permissions : {}

    # this contains lists of repo_ids for viewing records and viewing suppressed records
    self.scope = {}

    scope[:view_repository] = permissions
      .select{|k,v| v.include?('view_repository')}
      .keys.map{|uri| uri.split('/')[-1].to_i}

    # for the global '_archivesspace' repo, we end up with 0 (from the .to_i)
    # this is good because it simplifies the suppression filter
    # history records for global models have a repo_id of 0
    scope[:view_suppressed] = permissions
      .select{|k,v| v.include?('view_suppressed')}
      .keys.map{|uri| uri.split('/')[-1].to_i}
  end


  def get_history(model = false, id = false, version = false)
    filters = {}
    filters[:user] = user if user
    filters[:time] = time if time
    filters[:limit] = limit if limit
    filters[:version] = version if version

    (history, version, list) =
      if model && id
        history = History.new(model, id, scope)
        [
         history,
         history.version(version || time),
         history.versions(filters.reject{|k,v| mode.match(/^f/) && k == :version})
        ]
      else
        filters[:mode] = 'list'
        filters[:scope] = scope
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
        :diff => (history.diff(version.version, diff || find_previous_version(version.version, list)) rescue History::VersionNotFound && nil),
        :inline_diff => (history.inline_diff(version.version, diff || find_previous_version(version.version, list)) rescue History::VersionNotFound && nil),
        :can_restore => can_restore?(history.model, history.id, version.version),
        :versions => list,
      }

    end
  end


  def find_previous_version(current, versions)
    prev = 0
    versions.each do |v|
      prev = v.version if v.version < current && v.version > prev
    end
    prev
  end


  def diff_versions(model, id, a, b)
    History.diff(model, id, a, b, scope)
  end


  def can_restore?(model, id, version)
    return true if admin

    record_uri = History.new(model, id, scope).version(version).uri
    restore_perms = ArchivesSpaceService::Endpoint.permissions_for(:post, record_uri).map(&:to_s)
    perm_key = if (uri_match = record_uri.match(/^\/repositories\/\d+/))
                 uri_match[0]
               else
                 '_archivesspace'
               end

    ((permissions[perm_key] || []) & restore_perms).length == restore_perms.length
  end


  def restore_version!(model, id, version)
    raise AccessDeniedException.new("Access denied") unless can_restore?(model, id, version)

    (obj, json) = History.restore_version!(model, id, version)

    RequestContext.open(:repo_id => obj.respond_to?(:repo_id) ? obj.repo_id : nil) do
      {:status => 'Restored', :uri => obj.uri}
    end
  end

end
