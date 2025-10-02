require 'test_helper'

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  test 'index renders successfully' do
    get collections_path
    assert_response :success
    assert_template 'collections/index'
  end

  test 'show renders successfully with valid collection' do
    collection = Collection.create!(name: 'Test Collection', url: 'https://example.com')

    get collection_path(collection)
    assert_response :success
    assert_template 'collections/show'
  end

  test 'show returns 404 for non-existent collection' do
    get collection_path(id: 999999)
    assert_response :not_found
  end


  test 'committers page renders successfully' do
    collection = Collection.create!(name: 'Test Collection', url: 'https://example.com')

    get committers_collection_path(collection)
    assert_response :success
    assert_template 'collections/committers'
  end

  test 'committers_csv downloads CSV file' do
    collection = Collection.create!(name: 'Test Collection', url: 'https://example.com')
    project = collection.projects.create!(
      url: 'https://github.com/test/test',
      commits: {
        'committers' => [
          { 'name' => 'Test User', 'email' => 'test@example.com', 'count' => 5 }
        ]
      }
    )

    get committers_csv_collection_path(collection)
    assert_response :success
    assert_equal 'text/csv', response.media_type
    assert_match "#{collection.name}-committers.csv", response.headers['Content-Disposition']
  end
end
