require 'uri'
require 'bundler'
Bundler.require

CREDENTIALS = ['short', 'short']

configure do
  DataMapper.setup(:default, 'postgres://localhost/short')
end

class Url
  include DataMapper::Resource

  property :id, Serial
  property :original, String, :required => true
  property :view_count, Integer, :default => 0
  property :created_at, DateTime
  property :updated_at, DateTime

  validates_with_block(:original) { @original =~ URI::regexp(%w(http https)) }

  def identifier
    self.id.to_s(36)
  end

  def self.[](id)
    super id.to_i(36) - 1
  end

  def shortened
    if Sinatra::Application.port == 80
      "http://#{Sinatra::Application.bind}/#{identifier}"
    else
      "http://#{Sinatra::Application.bind}:#{Sinatra::Application.port}/#{identifier}"
    end
  end
end

helpers do
  def protected!
    auth = Rack::Auth::Basic::Request.new(request.env)

    unless auth.provided?
      response['WWW-Authenticate'] = %Q{Basic Realm="URL Shortener"}
      throw :halt, [401, 'Authorization Required']
    end

    unless auth.basic?
      throw :halt, [400, 'Bad Request']
    end

    if auth.provided? && CREDENTIALS == auth.credentials
      return true
    else
      throw :halt, [403, 'Forbidden']
    end
  end
end

get '/:url.json' do
  content_type :json

  url = Url[params[:url]]
  if url.nil?
    raise Sinatra::NotFound
  else
    return { :original => url.original, :shortened => url.shortened }.to_json
  end
end

get '/:url' do
  url = Url[params[:url]]
  if url.nil?
    raise Sinatra::NotFound
  else
    url.view_count += 1
    url.save
    redirect url.original
  end
end

post '/new' do
  protected!
  content_type :json

  if !params[:url]
    status 400
    return { :error => "'url' parameter is missing" }.to_json
  end

  url = Url.first_or_create(:original => params[:url])
  return { :original => url.original, :shortened => url.shortened }.to_json
end

not_found do
  redirect "http://titanous.com/", 302
end
