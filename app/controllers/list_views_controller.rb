class ListViewsController < ApplicationController
  def index
    @work_requests = WorkRequest
    .includes(:business, :required_skill, :assignments, assignments: :staff_member)
    .where.not(id: Assignment.where(status: "confirmed").select(:work_request_id)) # confirmedがついていないもの
    .order(:starts_at)

    @staff_members = StaffMember
    .includes(:skills, :availabilities)
    .order(:name)
  end
end
