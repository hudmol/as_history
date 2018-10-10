class HistoryController < ApplicationController

  skip_before_filter :unauthorised_access

  def index
    @recent = JSONModel::HTTP.get_json("/history")
  end


  def record

  end


  def version

  end
end
