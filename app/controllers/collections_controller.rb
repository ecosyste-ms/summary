class CollectionsController < ApplicationController
  def show
    @collection = Collection.find(params[:id])

    scope = @collection.projects

    if params[:keyword]
      scope = scope.where("keywords @> ARRAY[?]::varchar[]", params[:keyword])
    end

    @pagy, @projects = pagy(scope.order('id asc'))
  end

  def index
    @scope = Collection.all
    @pagy, @collections = pagy(@scope)
  end
end