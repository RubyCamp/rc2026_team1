class StaffMembersController < ApplicationController
  def index
    @staff_members = StaffMember.for_list
      .includes(:skills, :availabilities, assignments: :work_request)
      .order(:name)
  end
end
