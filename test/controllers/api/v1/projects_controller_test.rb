require 'test_helper'

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  test 'index returns json response' do
    get api_v1_projects_path
    assert_response :success
    assert_equal 'application/json', response.media_type
  end

  test 'index only includes synced projects' do
    synced_project = Project.create!(
      url: 'https://github.com/rails/rails',
      last_synced_at: Time.now
    )
    unsynced_project = Project.create!(
      url: 'https://github.com/test/test',
      last_synced_at: nil
    )

    get api_v1_projects_path
    assert_response :success
  end

  test 'show returns json for valid project' do
    project = Project.create!(url: 'https://github.com/rails/rails')

    get api_v1_project_path(project)
    assert_response :success
    assert_equal 'application/json', response.media_type
  end

  test 'show returns 404 for non-existent project' do
    get api_v1_project_path(id: '999999')
    assert_response :not_found
  end

  test 'lookup creates new project when not found' do
    url = 'https://github.com/testorg/testrepo'

    assert_difference 'Project.count', 1 do
      get lookup_api_v1_projects_path, params: { url: url }
    end

    project = Project.find_by(url: url)
    assert_not_nil project
    assert_response :success
  end

  test 'lookup returns existing project when found' do
    project = Project.create!(
      url: 'https://github.com/rails/rails',
      last_synced_at: 2.days.ago
    )

    assert_no_difference 'Project.count' do
      get lookup_api_v1_projects_path, params: { url: project.url }
    end

    assert_response :success
  end

  test 'lookup triggers sync for old project' do
    project = Project.create!(
      url: 'https://github.com/rails/rails',
      last_synced_at: 2.days.ago
    )

    get lookup_api_v1_projects_path, params: { url: project.url }
    assert_response :success
  end

  test 'lookup triggers sync for never synced project' do
    project = Project.create!(
      url: 'https://github.com/rails/rails',
      last_synced_at: nil
    )

    get lookup_api_v1_projects_path, params: { url: project.url }
    assert_response :success
  end

  test 'ping triggers async sync and returns json' do
    project = Project.create!(url: 'https://github.com/rails/rails')

    get ping_api_v1_project_path(project)
    assert_response :success
    assert_equal 'application/json', response.media_type

    json_response = JSON.parse(response.body)
    assert_equal 'pong', json_response['message']
  end

  test 'ping returns 404 for non-existent project' do
    get ping_api_v1_project_path(id: '999999')
    assert_response :not_found
  end
end
