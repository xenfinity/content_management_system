require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  @error_message = nil
  @filenames = Dir.entries("./data")
  @filenames.reject! do |filename|
    filename.start_with?('.')
  end
end

helpers do

end

get '/' do
  erb :index, layout: :layout
end

get '/:filename' do

  if @filenames.include?(params[:filename])
    file = File.open("./data/#{params[:filename]}")
    contents = file.read
    file.close
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect '/'
  end

  headers["Content-Type"] = "text/plain"
  contents
end