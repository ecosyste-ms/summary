require 'test_helper'

class Api::V1::CollectionsControllerTest < ActionDispatch::IntegrationTest
  test 'index returns json response' do
    get api_v1_collections_path
    assert_response :success
    assert_equal 'application/json', response.media_type
  end

  test 'index includes all collections' do
    collection1 = Collection.create!(name: 'Collection 1', url: 'https://example.com/1')
    collection2 = Collection.create!(name: 'Collection 2', url: 'https://example.com/2')

    get api_v1_collections_path
    assert_response :success
  end

  test 'show returns json for valid collection' do
    collection = Collection.create!(name: 'Test Collection', url: 'https://example.com')

    get api_v1_collection_path(collection)
    assert_response :success
    assert_equal 'application/json', response.media_type
  end

  test 'show returns 404 for non-existent collection' do
    get api_v1_collection_path(id: 999999)
    assert_response :not_found
  end

  test 'projects returns json of collection projects' do
    collection = Collection.create!(name: 'Test Collection', url: 'https://example.com')
    project = collection.projects.create!(
      url: 'https://github.com/test/test',
      last_synced_at: Time.now
    )

    get projects_api_v1_collection_path(collection)
    assert_response :success
    assert_equal 'application/json', response.media_type
  end

  test 'projects only returns synced projects' do
    collection = Collection.create!(name: 'Test Collection', url: 'https://example.com')
    synced_project = collection.projects.create!(
      url: 'https://github.com/rails/rails',
      last_synced_at: Time.now
    )
    unsynced_project = collection.projects.create!(
      url: 'https://github.com/test/test',
      last_synced_at: nil
    )

    get projects_api_v1_collection_path(collection)
    assert_response :success
  end

  test 'projects returns 404 for non-existent collection' do
    get projects_api_v1_collection_path(id: 999999)
    assert_response :not_found
  end
end
