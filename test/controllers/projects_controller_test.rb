require 'test_helper'

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test 'index renders successfully' do
    get projects_path
    assert_response :success
    assert_template 'projects/index'
  end

  test 'index displays paginated projects' do
    project = Project.create!(
      url: 'https://github.com/rails/rails',
      last_synced_at: Time.now,
      repository: { 'full_name' => 'rails/rails' }
    )

    get projects_path
    assert_response :success
    assert_select 'body'
  end

  test 'show renders successfully with valid project' do
    project = Project.create!(url: 'https://github.com/rails/rails')

    get project_path(project)
    assert_response :success
    assert_template 'projects/show'
  end

  test 'show returns 404 for non-existent project' do
    get project_path(id: '999999')
    assert_response :not_found
  end

  test 'lookup creates new project when not found' do
    url = 'https://github.com/testorg/testrepo'

    assert_difference 'Project.count', 1 do
      post lookup_projects_path, params: { url: url }
    end

    project = Project.find_by(url: url)
    assert_not_nil project
    assert_redirected_to project_path(project)
  end

  test 'lookup redirects to existing project when found' do
    project = Project.create!(url: 'https://github.com/rails/rails')

    assert_no_difference 'Project.count' do
      post lookup_projects_path, params: { url: project.url }
    end

    assert_redirected_to project_path(project)
  end

  test 'lookup strips whitespace from url' do
    url = '  https://github.com/rails/rails  '

    post lookup_projects_path, params: { url: url }

    project = Project.find_by(url: url.strip)
    assert_not_nil project
  end
end
