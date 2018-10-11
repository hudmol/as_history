class HistoryController < ApplicationController

  skip_before_filter :unauthorised_access

  def index
    @recent = JSONModel::HTTP.get_json("/history")
  end


  def record
    @version = JSONModel::HTTP.get_json("/history/#{params[:model]}/#{params[:id]}", :mode => 'full')
    render :version
  end


  def version
    @version = JSONModel::HTTP.get_json("/history/#{params[:model]}/#{params[:id]}/#{params[:version]}", :mode => 'full')
  end


  helper_method :skip_fields
  def skip_fields
    ['lock_version', 'created_by', 'last_modified_by', 'create_time', 'system_mtime', 'user_mtime', 'jsonmodel_type', 'uri', 'history']
  end

  helper_method :time_display
  def time_display(time)
    Time.utc(*time.split(/\D+/)[0..5]).getlocal
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

end
