class HistoryController < ApplicationController

  skip_before_filter :unauthorised_access

  def index
    args = {:mode => 'full'}
    args[:user] = params[:user] if params[:user]
    @version = JSONModel::HTTP.get_json("/history", args)
    render :version
  end


  def record
    @version = JSONModel::HTTP.get_json("/history/#{params[:model]}/#{params[:id]}", :mode => 'full')
    render :version
  end


  def version
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
    uri = '/' + ['history', model, id, version].join('/')
    uri += '?' + opts.map{|k,v| "#{k}=#{v}"}.join('&') unless opts.empty?
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

end
