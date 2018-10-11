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
end
