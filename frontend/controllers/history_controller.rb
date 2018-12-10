class HistoryController < ApplicationController

  set_access_control  "view_all_records" => [:index, :record, :version],
                      "administer_system" => [:restore]

  def index
    @title = "History | Recent updates"
    args = {:mode => 'full'}
    url = '/history'

    if params[:model]
      url += '/' + params[:model]
      @title += " to #{params[:model]} records"
    end

    if params[:user]
      args[:user] = params[:user]
      @title += " by #{params[:user]}"
    end

    if params[:time]
      args[:at] = params[:time]
      @title += " at #{params[:time]}"
    end

    @version = JSONModel::HTTP.get_json(url, args)

    flash.now[:info] = I18n.t('plugins.history.no_version_error_message') unless @version

    render :version
  end


  def restore
    resp = JSONModel::HTTP.post_form("/history/#{params[:model]}/#{params[:id]}/#{params[:version]}/restore")
    if resp.code === "200"
      flash[:success] = I18n.t('plugins.history.restore.success_message')
      id = JSONModel.parse_reference(ASUtils.json_parse(resp.body)['uri'])[:id]
      redirect_to(:controller => :history, :action => :record, :model => params[:model], :id => id)
    else
      flash[:error] = I18n.t('plugins.history.restore.error_message', :errors => resp.body)
      redirect_to(:controller => :history, :action => :record, :model => params[:model], :id => params[:id])
    end
  end


  def record
    @title = "History | Revisions for: #{params[:model]} / #{params[:id]}"
    @version = JSONModel::HTTP.get_json("/history/#{params[:model]}/#{params[:id]}", :mode => 'full')

    flash.now[:info] = I18n.t('plugins.history.no_version_error_message') unless @version

    render :version
  end


  def version
    @title = "History | Version: #{params[:model]} / #{params[:id]} .v#{params[:version]}"
    @version = JSONModel::HTTP.get_json("/history/#{params[:model]}/#{params[:id]}/#{params[:version]}", :mode => 'full', :diff => params[:diff])

    flash.now[:info] = I18n.t('plugins.history.no_version_error_message') unless @version
  end


  helper_method :skip_fields
  def skip_fields
    [
     'lock_version',
     'created_by',
     'last_modified_by',
     'create_time',
     'system_mtime',
     'user_mtime',
     'jsonmodel_type',
     'uri',
     'history',
     'agent_type',
     'tree',
    ]
  end


  helper_method :history_uri
  def history_uri(model, id, version, opts = {})
    uri_bits = ['history']
    if opts[:restore]
      uri_bits.push('restore')
      version = opts[:restore]
      opts.delete(:restore)
    end
    uri = '/' + (uri_bits + [model, id, version]).join('/')
    uri += '?' + opts.map{|k,v| "#{k}=#{v}"}.join('&') unless opts.empty?

    uri
  end


  helper_method :version_display
  def version_display(model, id, version)
    "#{model} / #{id} .v<strong>#{version}</strong>".html_safe
  end


  helper_method :model_pl
  def model_pl
    model = @version['data'].values.first['model']
    if model.start_with? 'agent_'
      'agents'
    elsif model == 'archival_object'
      'resources'
    else
      model.pluralize
    end
  end


  helper_method :json
  def json
    @version['json']
  end


  helper_method :data
  def data
    return {} unless @version
    @version['data'].values.first
  end


  helper_method :diff_version
  def diff_version
    dv = (params[:diff] || data.fetch('lock_version', 0) - 1).to_i
    dv < 0 ? false : dv
  end


  helper_method :supported_models
  def supported_models
    @supported_models ||= MemoryLeak::Resources.get(:history_models).map {|m| {:model => m.underscore, :label => m.gsub(/(.)([A-Z])/, '\1 \2')} }
  end


  helper_method :enum_translator
  def enum_translator(type, field, value)
    return value unless value.is_a?(String)
    return value if value.index(' ')

    case type
    when 'note'
      type = '_note'
      field = 'types'
    when 'linked_agent'
      field = 'archival_record_relators' if field == 'relator'
    when 'sub_container'
      type = 'container'
      field = 'type' if field.start_with?('type')
    end

    case field
    when 'language'
      type = 'language'
      field = 'iso639_2'
    when 'level'
      type = 'archival_record'
    end

    I18n.t("enumerations.#{type}_#{field}.#{value.to_s}", :default => I18n.t("enumerations.#{field}.#{value.to_s}", :default => value))
  end


  helper_method :version_set_label
  def version_set_label(params, data)
    label = params['id'] ? "#{params['model']} / #{params['id']} -- #{data['short_label']}"
                         : t('plugins.history.recent_updates')
    label += " to #{params['model']} records" if params['model'] && !params[:id]
    label += " by #{params['user']}" if params['user']
    label += " at #{params['time']}" if params['time']

    label
  end

end
