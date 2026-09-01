class ListViewsController < ApplicationController
  def index
    @work_requests = WorkRequest
    .includes(:business, :required_skill, :assignments, assignments: :staff_member)
    .where(assignments: { status: "draft" }) # Assignment の status が "draft" のものだけ残す
    .order(:starts_at)
  end
end
