class ListViewsController < ApplicationController
  def index
    @work_requests = WorkRequest
    .includes(:business, :required_skill, :assignments, assignments: :staff_member)
    .where(assignments: { status: "draft" }) # Assignmentのstatusがdraftのものだけ残す
    .order(:starts_at)
  end
end
