class ListViewsController < ApplicationController
  def index
    @assignments = Assignment.draft_for_confirmation
  end
end
