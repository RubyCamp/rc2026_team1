class ListViewsController < ApplicationController
  def index
    @assignments = Assignment.draft_for_confirmation
  end

  def confirm
    assignment = Assignment.find(params[:id])
    work_request = assignment.work_request
    staff_member = assignment.staff_member
    skill_missing = !StaffMember
      .skilled_for(work_request_id: work_request.id)
      .exists?(id: staff_member.id)

    if !assignment.draft? || skill_missing || !work_request.staffing_sufficient?
      redirect_to list_views_path,
        alert: "問題のない仮割り当てだけ確定できます。"
      return
    end

    Assignment.confirm!(id: assignment.id)
    redirect_to list_views_path,
      notice: "#{staff_member.name}さんの仮割り当てを確定しました。"
  rescue ActiveRecord::RecordNotFound
    redirect_to list_views_path,
      alert: "確定する仮割り当てが見つかりませんでした。"
  end
end
