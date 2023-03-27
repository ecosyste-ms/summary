class ProjectsController < ApplicationController
  def show
    @project = Project.find(params[:id])
  end

  def index
    @scope = Project.all
    @pagy, @projects = pagy(@scope)
  end
end