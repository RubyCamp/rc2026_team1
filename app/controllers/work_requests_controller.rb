class WorkRequestsController < ApplicationController
  def index
    @work_requests = WorkRequest
      .includes(:business, :required_skill, assignments: :staff_member)
      .order(:starts_at)
  end

  def show
    @work_request = WorkRequest
      .includes(:business, :required_skill, assignments: :staff_member)
      .find(params[:id])
    @assignable_staff_members = StaffMember.for_assignment.includes(:skills).where.not(
      id: Assignment.where(work_request: @work_request).select(:staff_member_id)
    )
  end

  def edit
    @work_request = WorkRequest.find(params[:id])
  end

  def assign
    assignment = Assignment.assign!(
      work_request_id: params[:id],
      staff_member_id: params.expect(:staff_member_id)
    )

    redirect_to assignment.work_request,
      notice: "#{assignment.staff_member.name}さんを仮割り当てしました。"
  rescue ActionController::ParameterMissing
    redirect_to work_request_path(params[:id]),
      alert: "スタッフを選択してください。"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to work_request_path(params[:id]),
      alert: error.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotFound
    redirect_to work_requests_path,
      alert: "割り当てる勤務依頼が見つかりませんでした。"
  end

  def unassign
    assignment = Assignment.find_by!(
      id: params.expect(:assignment_id),
      work_request_id: params[:id]
    )

    unless assignment.draft?
      redirect_to work_request_path(params[:id]),
        alert: "仮割り当てだけキャンセルできます。"
      return
    end

    staff_name = assignment.staff_member.name
    Assignment.unassign!(id: assignment.id)
    redirect_to work_request_path(params[:id]),
      notice: "#{staff_name}さんの仮割り当てをキャンセルしました。"
  rescue ActionController::ParameterMissing, ActiveRecord::RecordNotFound
    redirect_to work_request_path(params[:id]),
      alert: "キャンセルする仮割り当てが見つかりませんでした。"
  rescue ActiveRecord::RecordNotDestroyed => error
    redirect_to work_request_path(params[:id]),
      alert: error.record.errors.full_messages.to_sentence
  end

  def update
    @work_request = WorkRequest.update_details!(
      id: params[:id],
      attributes: work_request_params
    )

    redirect_to @work_request, notice: "勤務依頼の備考を更新しました。"
  rescue ActiveRecord::RecordInvalid => error
    raise unless error.record.is_a?(WorkRequest)

    @work_request = error.record
    render :edit, status: :unprocessable_content
  rescue ActiveRecord::RecordNotFound
    redirect_to work_requests_path, alert: "更新する勤務依頼が見つかりませんでした。"
  end

  private

  def work_request_params
    params.expect(work_request: [ :notes ])
  end
end
