class HistoryController < ApplicationController

  set_access_control  "view_all_records" => [:index, :record, :version],
                      "administer_system" => [:restore]

  def index
    @title = "History | Recent updates"
    args = {:mode => 'full'}
    args[:user] = params[:user] if params[:user]
    @title += " by #{args[:user]}" if args[:user]
    @version = JSONModel::HTTP.get_json("/history", args)
    render :version
  end


  def restore
    resp = JSONModel::HTTP.post_form("/history/#{params[:model]}/#{params[:id]}/#{params[:version]}/restore")
    if resp.code === "200"
      flash[:success] = I18n.t('plugins.history.restore.success_message')
    else
      flash[:error] = I18n.t('plugins.history.restore.error_message', :errors => resp.body)
    end
    redirect_to(:controller => :history, :action => :record, :model => params[:model], :id => params[:id])
  end


  def record
    @title = "History | Revisions for: #{params[:model]} / #{params[:id]}"
    @version = JSONModel::HTTP.get_json("/history/#{params[:model]}/#{params[:id]}", :mode => 'full')
    render :version
  end


  def version
    @title = "History | Version: #{params[:model]} / #{params[:id]} .v#{params[:version]}"
    @version = JSONModel::HTTP.get_json("/history/#{params[:model]}/#{params[:id]}/#{params[:version]}", :mode => 'full', :diff => params[:diff])
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


  helper_method :time_display
  def time_display(time)
    Time.utc(*time.split(/\D+/)[0..5]).getlocal.to_s.sub(/ [^ ]+$/, '')
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
    @version['data'].values.first
  end


  helper_method :diff_version
  def diff_version
    dv = (params[:diff] || data['lock_version'] - 1).to_i
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

end
