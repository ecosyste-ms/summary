class Api::V1::ProjectsController < Api::V1::ApplicationController
  def index
    @projects = Project.all
    @pagy, @projects = pagy(@projects)
  end

  def show
    @project = Project.find(params[:id])
  end
end