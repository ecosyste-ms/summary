class Api::V1::ProjectsController < Api::V1::ApplicationController
  def index
    @projects = Project.all.where.not(last_synced_at: nil)
    @pagy, @projects = pagy(@projects)
  end

  def show
    @project = Project.find(params[:id])
  end
end