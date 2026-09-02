class WorkRequest < ApplicationRecord
  belongs_to :business
  belongs_to :required_skill,
             class_name: "Skill",
             inverse_of: :work_requests

  has_many :assignments, dependent: :destroy
  has_many :staff_members, through: :assignments
  has_many :skills, through: :staff_members

  enum :status,
       {
         open: "open",
         draft: "draft",
         confirmed: "confirmed",
         cancelled: "cancelled"
       },
       validate: true

  validates :title, :starts_at, :ends_at, presence: true
  validates :required_staff_count,
            numericality: {
              only_integer: true,
              greater_than: 0
            }

  validate :ends_at_after_starts_at

  def self.for_list
    includes(:business, :required_skill, :assignments).order(:starts_at)
  end

  def self.with_assignment_details
    includes(assignments: :staff_member)
  end

  def self.with_staffing_shortage
    left_joins(:assignments)
      .group(:id)
      .having("COUNT(assignments.id) < work_requests.required_staff_count")
      .order(:starts_at)
  end

  def active_assignment_count
    assignments.size
  end

  def staffing_shortage_count
    [ required_staff_count - active_assignment_count, 0 ].max
  end

  def staffing_sufficient?
    staffing_shortage_count.zero?
  end

  def self.register!(attributes:)
  transaction do
    create!(attributes).tap do |work_request|
      ChangeEvent.record!(
        target_type: :work_request,
        target_id: work_request.id,
        action_type: :created,
        summary: "勤務依頼「#{work_request.title}」を登録しました"
      )
    end
  end
end

def self.update_details!(id:, attributes:)
  transaction do
    find(id).tap do |work_request|
      work_request.assign_attributes(attributes)
      work_request.save!

      next unless business_changes?(work_request)

      ChangeEvent.record!(
        target_type: :work_request,
        target_id: work_request.id,
        action_type: :updated,
        summary: "勤務依頼「#{work_request.title}」を更新しました"
      )
    end
  end
end

def self.cancel!(id:)
  transaction do
    find(id).tap do |work_request|
      work_request.cancelled!

      next unless business_changes?(work_request)

      ChangeEvent.record!(
        target_type: :work_request,
        target_id: work_request.id,
        action_type: :cancelled,
        summary: "勤務依頼「#{work_request.title}」を取り消しました"
      )
    end
  end
end

def self.remove!(id:)
  transaction do
    find(id).tap do |work_request|
      unless work_request.draft? && work_request.assignments.none?
        message = "下書きで割当のない勤務依頼だけ削除できます"
        work_request.errors.add(:base, message)

        raise ActiveRecord::RecordNotDestroyed.new(
          message,
          work_request
        )
      end

      target_id = work_request.id
      title = work_request.title

      work_request.destroy!

      ChangeEvent.record!(
        target_type: :work_request,
        target_id: target_id,
        action_type: :deleted,
        summary: "勤務依頼「#{title}」を削除しました"
      )
    end
  end
end

def self.business_changes?(record)
  record.saved_changes.except("updated_at").any?
end

private_class_method :business_changes?
  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, "は開始日時より後にしてください")
  end
end
