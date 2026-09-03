class ListViewsController < ApplicationController
  def index
    @businesses = Business.for_selection
    assignments = Assignment.draft_for_confirmation
    assignments = assignments.where(
      work_requests: { business_id: params[:business_id] }
    ) if params[:business_id].present?
    assignments = filter_assignments_by_date(assignments)

    @assignments = assignments.select { |assignment| judgment_match?(assignment) }
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
      return render_assignment_status(assignment) if modal_toggle_request?
      redirect_back fallback_location: list_views_path,
        alert: "問題のない仮割り当てだけ確定できます。"
      return
    end

    Assignment.confirm!(id: assignment.id)
    return render_assignment_status(assignment) if modal_toggle_request?
    redirect_back fallback_location: list_views_path,
      notice: "#{staff_member.name}さんの仮割り当てを確定しました。"
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: list_views_path,
      alert: "確定する仮割り当てが見つかりませんでした。"
  end

  def unconfirm
    assignment = Assignment.find(params[:id])

    unless assignment.confirmed?
      return render_assignment_status(assignment) if modal_toggle_request?
      redirect_back fallback_location: confirmed_list_views_path,
        alert: "確定済みの割り当てだけ未確定に戻せます。"
      return
    end

    assignment.draft!
    return render_assignment_status(assignment) if modal_toggle_request?
    redirect_back fallback_location: confirmed_list_views_path,
      notice: "#{assignment.staff_member.name}さんの割り当てを未確定に戻しました。"
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: confirmed_list_views_path,
      alert: "未確定に戻す割り当てが見つかりませんでした。"
  end

  private

  def filter_assignments_by_date(assignments)
    date_range = case params[:date_filter]
    when "today"
      Time.zone.today.all_day
    when "week"
      Time.zone.today.all_week
    when "date"
      return assignments if params[:work_date].blank?

      Date.iso8601(params[:work_date]).all_day
    end

    return assignments unless date_range

    assignments.where(work_requests: { starts_at: date_range })
  rescue ArgumentError
    assignments
  end

  def judgment_match?(assignment)
    work_request = assignment.work_request
    skill_missing = !StaffMember
      .skilled_for(work_request_id: work_request.id)
      .exists?(id: assignment.staff_member_id)
    staffing_shortage = !work_request.staffing_sufficient?

    case params[:judgment]
    when "attention"
      skill_missing || staffing_shortage
    when "ok"
      !skill_missing && !staffing_shortage
    when "skill_missing"
      skill_missing
    when "staffing_shortage"
      staffing_shortage
    else
      true
    end
  end

  def modal_toggle_request?
    params[:modal_toggle] == "true" && request.format.turbo_stream?
  end

  def render_assignment_status(assignment)
    render turbo_stream: turbo_stream.replace(
      "assignment-status-#{assignment.id}",
      partial: "shared/assignment_status_button",
      locals: { assignment: assignment }
    )
  end
end
