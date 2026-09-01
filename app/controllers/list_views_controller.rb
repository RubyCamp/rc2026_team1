class ListViewsController < ApplicationController
  def index
    @profiles = WorkRequest.all
  end

  def debug
    @profile = WorkRequest.find(1)
  end
end
