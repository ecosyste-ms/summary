class CollectionsController < ApplicationController
  def show
    @collection = Collection.find(params[:id])

    scope = @collection.projects.order('score desc').where.not(last_synced_at: nil)

    if params[:language].present?
      scope = scope.language(params[:language])
    end

    if params[:keyword].present?
      scope = scope.where("keywords @> ARRAY[?]::varchar[]", params[:keyword])
    end

    if params[:committer].present?
      scope = @collection.committers_projects(params[:committer])
    end

    if params[:dependency].present?
      scope = @collection.dependency_projects(params[:dependency])
    end

    # scope = scope.reject{|p| p.repository.present? && p.repository['source_name'].present? && p.repository['stargazers_count'] == 0 }

    @pagy, @projects = pagy_array(scope)
  end

  def index
    @scope = Collection.all
    @pagy, @collections = pagy(@scope)
  end
end