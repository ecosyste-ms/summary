class CollectionsController < ApplicationController
  def show
    @collection = Collection.find(params[:id])

    scope = @collection.projects.order('id asc')

    if params[:keyword]
      scope = scope.where("keywords @> ARRAY[?]::varchar[]", params[:keyword])
    end

    if params[:committer]
      scope = @collection.committers_projects(params[:committer])
    end

    @pagy, @projects = pagy_array(scope)
  end

  def index
    @scope = Collection.all
    @pagy, @collections = pagy(@scope)
  end
end