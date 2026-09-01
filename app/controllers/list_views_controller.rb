class ListViewsController < ApplicationController
  def index
    @work_requests = WorkRequest
    .includes(:business, :required_skill, :assignments, assignments: :staff_member)
    .order(:starts_at)

    # @work_requests = if work_requests.assignments.status == "draft"

    logger.debug("------------------------")
    # logger.debug(work_requests)
    logger.debug(@work_requests.select { |assignments|  })
    logger.debug("------------------------")
    logger.debug("----------------------2--")
    @work_requests.select do |work_request|
                  work_request.assignments.select { |status|  } == "draft"
                  logger.debug(work_request.assignments.select(:status, :id).filter { |assignment|  assignment.status == "draft" })
                end
                logger.debug("-----------------------2-")

    # @work_requests = []
  end
end
