# frozen_string_literal: true

class Api::V1::CategoriesController < Api::V1::BaseController
  before_action :ensure_read_scope

  def index
    family = current_resource_owner.family
    @categories = family.categories.alphabetically.includes(:subcategories)

    # Optional filtering by classification: ?classification=expense|income
    if params[:classification].present?
      @categories = @categories.where(classification: params[:classification])
    end

    render :index
  rescue => e
    Rails.logger.error "CategoriesController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
    end
end
