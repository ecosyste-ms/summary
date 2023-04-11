class Api::V1::CollectionsController < Api::V1::ApplicationController
  def index
    @collections = Collection.all
    @pagy, @collections = pagy(@collections)
  end

  def show
    @collection = Collection.find(params[:id])
  end

  def projects
    @collection = Collection.find(params[:id])
    @projects = @collection.projects
    @pagy, @projects = pagy(@projects)
    render 'api/v1/projects/index'
  end
end