class ProjectsController < ApplicationController
  def show
    @project = Project.find(params[:id])
  end

  def index
    @scope = Project.all.where.not(last_synced_at: nil).where.not(repository: nil).order('created_at DESC')
    @pagy, @projects = pagy(@scope)
  end

  def lookup
    @project = Project.find_by(url: params[:url])
    if @project.nil?
      @project = Project.create(url: params[:url])
      @project.sync_async
    end
    redirect_to @project
  end
end