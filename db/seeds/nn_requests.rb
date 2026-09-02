module NnRequestsSeed
  module_function

  def run(people)
    skills = people.fetch(:skills)
    staff_members = people.fetch(:staff_members)

    businesses = {}
    [
      [ :hotel, "みらいホテル", "担当者01", "03-0000-0101" ],
      [ :hall, "あおぞら会館", "担当者02", "03-0000-0102" ],
      [ :office, "中央オフィス", "担当者03", "03-0000-0103" ]
    ].each do |key, name, contact_name, contact_phone|
      businesses[key] = NnSeed.upsert_by(
        Business,
        { name: name },
        contact_name: contact_name,
        contact_phone: contact_phone,
        active: true
      )
    end

    request_specs = [
      [ :hotel, "客室清掃01", "NN_CLEANING", 20, 10, 12, 1, :open ],
      [ :hotel, "宴会場清掃01", "NN_CLEANING", 20, 13, 17, 3, :open ],
      [ :hall, "受付案内01", "NN_RECEPTION", 20, 10, 12, 2, :open ],
      [ :hall, "式典配膳01", "NN_SERVING", 20, 14, 18, 2, :confirmed ],
      [ :office, "調理補助01", "NN_KITCHEN", 20, 18, 20, 1, :open ],
      [ :hotel, "朝食配膳01", "NN_SERVING", 21, 7, 10, 2, :confirmed ],
      [ :hall, "会館受付01", "NN_RECEPTION", 21, 10, 14, 2, :draft ],
      [ :office, "厨房準備01", "NN_KITCHEN", 21, 13, 17, 2, :open ],
      [ :hotel, "共用部清掃01", "NN_CLEANING", 22, 9, 12, 2, :open ],
      [ :hall, "来場者受付01", "NN_RECEPTION", 22, 13, 16, 1, :open ],
      [ :office, "弁当準備01", "NN_KITCHEN", 22, 16, 20, 3, :open ],
      [ :hotel, "取消清掃01", "NN_CLEANING", 22, 10, 12, 1, :cancelled ],
      [ :office, "スキル確認01", "NN_RECEPTION", 22, 10, 12, 1, :open ]
    ]

    18.times do |index|
      day = 23 + (index % 2)
      start_hour = 9 + ((index * 2) % 8)
      end_hour = start_hour + [ 2, 3, 4 ][index % 3]
      skill_code = [ "NN_CLEANING", "NN_SERVING", "NN_RECEPTION", "NN_KITCHEN" ][index % 4]
      business_key = [ :hotel, :hall, :office ][index % 3]
      required_count = [ 1, 1, 2, 3 ][index % 4]
      status = [ :open, :open, :draft, :confirmed ][index % 4]

      request_specs << [
        business_key,
        format("定期業務%02d", index + 1),
        skill_code,
        day,
        start_hour,
        end_hour,
        required_count,
        status
      ]
    end

    requests = {}

    request_specs.each do |business_key, title, skill_code, day, start_hour, end_hour, required_count, status|
      requests[title] = NnSeed.upsert_by(
        WorkRequest,
        { business: businesses.fetch(business_key), title: title },
        required_skill: skills.fetch(skill_code),
        starts_at: Time.zone.local(2026, 8, day, start_hour),
        ends_at: Time.zone.local(2026, 8, day, end_hour),
        required_staff_count: required_count,
        status: status
      )
    end

    assignment_specs = {
      "客室清掃01" => [ [ "NN001", :draft ] ],
      "宴会場清掃01" => [ [ "NN001", :draft ], [ "NN005", :draft ] ],
      "式典配膳01" => [ [ "NN002", :confirmed ], [ "NN006", :confirmed ] ],
      "朝食配膳01" => [ [ "NN005", :confirmed ] ],
      "会館受付01" => [ [ "NN003", :draft ] ],
      "厨房準備01" => [ [ "NN004", :draft ] ],
      "共用部清掃01" => [ [ "NN007", :draft ], [ "NN008", :draft ] ],
      "来場者受付01" => [ [ "NN011", :draft ] ],
      "弁当準備01" => [ [ "NN004", :draft ], [ "NN008", :draft ] ],
      "スキル確認01" => [ [ "NN001", :draft ] ]
    }

    assignment_specs.each do |title, assignments|
      assignments.each do |staff_key, status|
        NnSeed.upsert_by(
          Assignment,
          {
            work_request: requests.fetch(title),
            staff_member: staff_members.fetch(staff_key)
          },
          status: status
        )
      end
    end

    requests
  end
end
