class StaffMembersController < ApplicationController
  def index
    @staff_members = StaffMember.for_list
      .includes(:skills, :availabilities)
      .order(:name)
  end
end
