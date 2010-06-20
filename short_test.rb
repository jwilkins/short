require 'short'
require 'test/unit'
Bundler.require(:test)

set :environment, :test

class UrlTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    DataMapper.auto_migrate!
    Url.create(:original => 'http://www.amazon.com')
    Url.create(:original => 'http://www.ebay.com')
    Url.create(:original => 'http://news.ycombinator.com')
  end

  def set_authorization!
    authorize  'short', 'short'
  end

  def test_identifier_should_redirect_to_original_if_url_identifier_exists
    get '/1'
    assert last_response.redirect?
    follow_redirect!
    assert_equal 'http://www.amazon.com/', last_request.url

    get '/2'
    assert last_response.redirect?
    follow_redirect!
    assert_equal 'http://www.ebay.com/', last_request.url

    get '/3'
    assert last_response.redirect?
    follow_redirect!
    assert_equal 'http://news.ycombinator.com/', last_request.url
  end

  def test_identifier_should_return_json_if_requested
    get '/1.json'
    assert_equal 'application/json', last_response.headers['Content-Type']
    response = JSON.parse(last_response.body)
    assert_equal 'http://www.amazon.com', response['original']
  end

  def test_identifier_should_update_the_last_access_date
    Timecop.freeze do
      get '/1'
      url = Url.first(:id => 1)
      assert_equal DateTime.now, url.updated_at
    end
  end

  def test_identifier_should_increment_view_count
    url = Url.first(:id => 1)
    assert_equal url.view_count, 0
    get '/1'
    url.reload
    assert_equal url.view_count, 1
  end

  def test_identifier_should_redirect_to_default_host_if_url_identifier_does_not_exist
    get '/abcde'
    assert last_response.redirect?
    assert_equal 302, last_response.status
    follow_redirect!
    assert_equal 'http://titanous.com/', last_request.url
  end

  def test_new_should_return_status_401_if_no_authentication_info_provided
    post '/new'
    assert_equal 401, last_response.status
  end

  def test_new_should_return_status_403_if_authentication_info_incorrect
    authorize  'short', 'incorrect-password'
    post '/new'
    assert_equal 403, last_response.status
  end

  def test_new_content_type_should_be_json
    set_authorization!
    post '/new'
    assert_equal 'application/json', last_response.headers['Content-Type']
  end

  def test_new_should_return_status_400_if_params_are_missing
    set_authorization!
    post '/new'
    assert_equal 400, last_response.status
  end

  def test_new_should_return_error_identifier_if_params_are_missing
    set_authorization!
    post '/new'
    response_hash = JSON.parse(last_response.body)
    assert response_hash.has_key?('error')
    assert "'url' parameter is missing", response_hash['error']
  end

  def test_new_should_create_a_new_record_if_url_does_not_exist
    set_authorization!
    url_count = Url.all.length
    post '/new', { :url => 'http://www.google.com' }
    assert_equal url_count + 1, Url.all.length
  end

  def test_new_should_not_create_a_new_record_if_url_already_exists
    set_authorization!
    url_count = Url.all.length
    post '/new', { :url => 'http://www.amazon.com' }
    assert_equal url_count, Url.all.length
  end

  def test_new_should_return_short_url_and_original
    set_authorization!
    post '/new', { :url => 'http://www.amazon.com' }
    new_url = Url.first(:original => 'http://www.amazon.com')
    response_hash = JSON.parse(last_response.body)
    assert_equal new_url.shortened, response_hash['shortened']
    assert_equal 'http://www.amazon.com', response_hash['original']
  end
end
