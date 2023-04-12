class CollectionsController < ApplicationController
  def show
    @collection = Collection.find(params[:id])

    scope = @collection.projects.order('id asc').where.not(last_synced_at: nil)

    scope = scope.reject{|p| p.repository.present? && p.repository['source_name'].present? && p.repository['stargazers_count'] == 0 }

    if params[:keyword].present?
      scope = scope.where("keywords @> ARRAY[?]::varchar[]", params[:keyword])
    end

    if params[:committer].present?
      scope = @collection.committers_projects(params[:committer])
    end

    if params[:dependency].present?
      scope = @collection.dependency_projects(params[:dependency])
    end

    @pagy, @projects = pagy_array(scope.to_a.sort_by(&:score).reverse)
  end

  def index
    @scope = Collection.all
    @pagy, @collections = pagy(@scope)
  end
end