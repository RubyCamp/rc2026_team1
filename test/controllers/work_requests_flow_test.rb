require "test_helper"

class WorkRequestsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @business = Business.create!(
      name: "テスト会館",
      contact_name: "担当者",
      contact_phone: "00-0000-0000"
    )
    @required_skill = Skill.create!(code: "RECEPTION_#{SecureRandom.hex(4)}", name: "受付")
    @work_request = WorkRequest.create!(
      business: @business,
      required_skill: @required_skill,
      title: "受付業務",
      starts_at: Time.zone.local(2026, 8, 20, 10),
      ends_at: Time.zone.local(2026, 8, 20, 12),
      required_staff_count: 1,
      notes: "集合場所は正面玄関"
    )
  end

  test "詳細画面に備考と編集リンクを表示する" do
    get work_request_path(@work_request)

    assert_response :success
    assert_select "h2", text: "備考"
    assert_select "dt", text: "勤務時間"
    assert_select "p", text: "集合場所は正面玄関"
    assert_select "a[href=?]", edit_work_request_path(@work_request), text: "備考を編集"
  end

  test "スキル不足と時間重複があっても仮割り当てして警告を表示する" do
    other_skill = Skill.create!(code: "OTHER_#{SecureRandom.hex(4)}", name: "清掃")
    staff_member = StaffMember.create!(
      name: "警告対象スタッフ",
      employment_status: :active
    )
    StaffSkill.create!(
      staff_member: staff_member,
      skill: other_skill,
      proficiency_label: "経験あり"
    )

    overlapping_request = WorkRequest.create!(
      business: @business,
      required_skill: other_skill,
      title: "重複する勤務依頼",
      starts_at: Time.zone.local(2026, 8, 20, 11),
      ends_at: Time.zone.local(2026, 8, 20, 13),
      required_staff_count: 1,
      status: :open
    )
    Assignment.assign!(
      work_request_id: overlapping_request.id,
      staff_member_id: staff_member.id
    )

    get work_request_path(@work_request)
    assert_response :success
    assert_select ".dropdown-menu" do
      assert_select "button.dropdown-item", text: /警告対象スタッフ.*清掃/
      assert_select ".badge.text-bg-danger", text: "スキル不足"
      assert_select ".badge.text-bg-danger", text: "時間重複"
      assert_select "input[name=staff_member_id][value=?]", staff_member.id.to_s
    end

    assert_difference("Assignment.count", 1) do
      post assign_work_request_path(@work_request), params: {
        staff_member_id: staff_member.id
      }
    end

    assignment = Assignment.find_by!(
      work_request: @work_request,
      staff_member: staff_member
    )
    assert assignment.draft?
    assert_redirected_to work_request_path(@work_request)

    follow_redirect!
    assert_response :success
    assert_select "li.list-group-item-danger" do
      assert_select "strong", text: staff_member.name
      assert_select ".badge.text-bg-danger", text: "スキル不足"
      assert_select ".badge.text-bg-danger", text: "時間重複"
    end
  end

  test "詳細画面の下書き割り当てを確定またはキャンセルする" do
    staff_member = StaffMember.create!(
      name: "確定対象スタッフ",
      employment_status: :active
    )
    StaffSkill.create!(
      staff_member: staff_member,
      skill: @required_skill,
      proficiency_label: "経験あり"
    )
    assignment = Assignment.assign!(
      work_request_id: @work_request.id,
      staff_member_id: staff_member.id
    )

    get work_request_path(@work_request)
    assert_response :success
    assert_select "form[action=?]", confirm_list_view_path(assignment) do
      assert_select "button", text: "確定する"
    end
    assert_select "form[action=?]", unassign_work_request_path(@work_request) do
      assert_select "button", text: "キャンセル"
    end

    patch confirm_list_view_path(assignment),
      headers: { "HTTP_REFERER" => work_request_url(@work_request) }

    assert assignment.reload.confirmed?
    assert_redirected_to work_request_path(@work_request)

    assignment.draft!
    assert_difference("Assignment.count", -1) do
      delete unassign_work_request_path(@work_request),
        params: { assignment_id: assignment.id }
    end
    assert_redirected_to work_request_path(@work_request)
  end

  test "必要人数分のスタッフ確定後に勤務依頼の受付を終了する" do
    staff_member = StaffMember.create!(
      name: "受付終了対象スタッフ",
      employment_status: :active
    )
    StaffSkill.create!(
      staff_member: staff_member,
      skill: @required_skill,
      proficiency_label: "経験あり"
    )
    assignment = Assignment.assign!(
      work_request_id: @work_request.id,
      staff_member_id: staff_member.id
    )

    @work_request.open!
    get work_request_path(@work_request)
    assert_select "button", text: "受付を終了する", count: 0

    Assignment.confirm!(id: assignment.id)
    get work_request_path(@work_request)
    assert_select "form[action=?]", confirm_work_request_path(@work_request) do
      assert_select "button", text: "受付を終了する"
    end

    assert_difference("ChangeEvent.count", 1) do
      patch confirm_work_request_path(@work_request)
    end

    assert_predicate @work_request.reload, :confirmed?
    assert_redirected_to work_request_path(@work_request)

    follow_redirect!
    assert_select ".badge", text: "確定"
    assert_select "button", text: "受付を終了する", count: 0
  end

  test "備考だけを更新して詳細画面へ戻る" do
    assert_difference("ChangeEvent.count", 1) do
      patch work_request_path(@work_request), params: {
        work_request: {
          notes: "変更後は裏口へ集合",
          title: "この値は更新しない"
        }
      }
    end

    assert_redirected_to work_request_path(@work_request)
    assert_equal "変更後は裏口へ集合", @work_request.reload.notes
    assert_equal "受付業務", @work_request.title

    follow_redirect!
    assert_select ".alert-success", text: /勤務依頼の備考を更新しました/
    assert_select "p", text: "変更後は裏口へ集合"
  end

  test "備考編集画面を表示する" do
    get edit_work_request_path(@work_request)

    assert_response :success
    assert_select "h1", text: "勤務依頼の備考を編集"
    assert_select "form[action=?]", work_request_path(@work_request)
    assert_select "textarea[name=?]", "work_request[notes]", text: "集合場所は正面玄関"
  end

  test "勤務依頼以外のRecordInvalidは編集画面へ渡さない" do
    error = ActiveRecord::RecordInvalid.new(ChangeEvent.new)
    original = WorkRequest.method(:update_details!)
    WorkRequest.define_singleton_method(:update_details!) { |**| raise error }

    patch work_request_path(@work_request), params: {
      work_request: { notes: "変更後の備考" }
    }

    assert_response :unprocessable_content
    assert_not_includes response.body, "勤務依頼の備考を編集"
  ensure
    WorkRequest.define_singleton_method(:update_details!, original)
  end
end
