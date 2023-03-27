class CollectionsController < ApplicationController
  def show
    @collection = Collection.find(params[:id])
    @pagy, @projects = pagy(@collection.projects.order('id asc'))
  end

  def index
    @scope = Collection.all
    @pagy, @collections = pagy(@scope)
  end
end