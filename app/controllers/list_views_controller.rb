class ListViewsController < ApplicationController
  def index
    @assignments = Assignment.draft_for_confirmation
  end

  def confirmed
    @assignments = Assignment
      .includes(
        { staff_member: { staff_skills: :skill } },
        work_request: [ :business, :required_skill ]
      )
      .confirmed
      .order("work_requests.starts_at", :created_at)
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

  def unconfirm
    assignment = Assignment.find(params[:id])

    unless assignment.confirmed?
      redirect_to confirmed_list_views_path,
        alert: "確定済みの割り当てだけ未確定に戻せます。"
      return
    end

    assignment.draft!
    redirect_to confirmed_list_views_path,
      notice: "#{assignment.staff_member.name}さんの割り当てを未確定に戻しました。"
  rescue ActiveRecord::RecordNotFound
    redirect_to confirmed_list_views_path,
      alert: "未確定に戻す割り当てが見つかりませんでした。"
  end
end
