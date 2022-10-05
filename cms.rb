require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

EXTENSIONS = [".txt", ".md"]

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :font_family, 'sans-serif'
  set :erb, :escape_html => true
end

before do
  @error_message = nil
  @filenames = Dir.entries(data_path)
  @filenames.reject! do |filename|
    reject_filename?(filename)
  end
end

helpers do

end

def reject_filename?(filename)
  filename.start_with?('.') || 
    File.extname(filename) == ".bak" ||
    File.extname(filename) == ""
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_file_content(path)
  content = File.read(path)

  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def render_markdown(content)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(content)
end

def write_contents_to_file(file_path, content)
  file = File.open(file_path, 'w')
  file.write(content)
  file.close
end

def delete_file(file_path)
  File.delete(file_path)
end

def authenticate(username, password)
  users = load_user_credentials
  stored_hash = users[username]

  hashed_pw = BCrypt::Password.new(stored_hash) if stored_hash
  hashed_pw == password
end

def valid_credentials(username, password)
  valid_username?(username) && valid_password?(password)
end

def valid_username?(username)
  users = load_user_credentials

  if username.size < 3
    session[:error] = "Username is too short, must be at least 3 characters long."
    redirect '/users/signup'
  elsif users.keys.include?(username)
    session[:error] = "Username already exists."
    redirect '/users/signup'
  else
    true
  end
end

def valid_password?(password)
  if password.size < 8
    session[:error] = "Password is too short, must be at least 8 characters long."
    redirect '/users/signup'
  elsif password.match?(/^([^A-Z]*|[^a-z]*|[^\d]*)$/)
    session[:error] = "Password must contain at least one uppercase letter, lowercase letter and number"
    redirect '/users/signup'
  else
    true
  end
end

def load_user_credentials
  YAML.load_file(credentials_path)
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def user_signed_in?(session)
  session[:signed_in]
end

def redirect_protected_content(session)
  unless user_signed_in?(session)
    session[:error] = "You must be signed in to do that."
    redirect '/'
  end
end

def validate_extension(extension)
  EXTENSIONS.include?(extension)
end

def redirect_if_invalid(filename, redirect_location)
  extension = File.extname(filename)
  session[:filename] = filename
  if filename.empty?
    session[:error] = "A file name is required"
    redirect redirect_location
  elsif extension.empty?
    session[:error] = "A file extension is required (e.g. '.txt', '.md')"
    redirect redirect_location
  elsif !validate_extension(extension)
    session[:error] = "Invalid file extension - Valid extensions: .txt, .md"
    redirect redirect_location
  end
end


get '/' do
  erb :index, layout: :layout
end 

get '/users/signin' do
  erb :sign_in, layout: :layout
end

post '/users/signin' do
  username = params[:username]
  password = params[:password]
  
  if authenticate(username, password)
    session[:success] = "Welcome #{username}!"
    session[:signed_in] = true
    session[:username] = username
    redirect '/'
  else
    session[:error] = "Invalid Credentials"
    redirect '/users/signin'
  end
end

post '/users/signout' do
  session[:signed_in] = false
  session[:username] = nil
  session[:success] = "Successfully signed out"
  redirect '/'
end

get '/users/signup' do
  erb :sign_up, layout: :layout
end

post '/users/signup' do
  username = params[:username]
  password = params[:password]
  users = load_user_credentials
  
  if valid_credentials(username, password)
    hashed_pw = BCrypt::Password.create(password).to_str
    users[username] = hashed_pw
    File.open(credentials_path, "w") { |file| file.write(users.to_yaml) }
    session[:success] = "#{username} successfully signed up! Please sign in below"
    redirect '/'
  else
    session[:error] = "Invalid Credentials"
    redirect '/users/signup'
  end
end

get '/new' do
  redirect_protected_content(session)
  erb :new, layout: :layout
end

get '/:filename' do
  filename = params[:filename]
  file_path = File.join(data_path, filename)

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{filename} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do
  redirect_protected_content(session)

  filename = params[:filename]
  file_path = File.join(data_path, filename)

  if File.exist?(file_path)
    @content = File.read(file_path)
    @filename = filename
    erb :edit_file, layout: :layout
  else
    session[:error] = "#{filename} does not exist."
    redirect '/'
  end
end

post '/:filename/write' do
  redirect_protected_content(session)
  filename = params[:filename]
  file_path = File.join(data_path, filename)

  new_filename = params[:new_filename]
  new_file_path = File.join(data_path, new_filename) if new_filename

  content = params[:content]

  if !File.exist?(file_path)
    session[:error] = "#{filename} does not exist."
  elsif filename == new_filename
    session[:success] = "#{filename} has been updated."
    write_contents_to_file(file_path, content)
  else
    redirect_if_invalid(new_filename, "/#{filename}/edit")

    session[:success] = "#{filename} was renamed to #{new_filename}"
    delete_file(file_path)
    File.new(new_file_path, "w")
    write_contents_to_file(new_file_path, content)
  end
  redirect '/'
end

post '/:filename/delete' do
  redirect_protected_content(session)
  filename = params[:filename]
  file_path = File.join(data_path, filename)

  if File.exist?(file_path)
    session[:success] = "#{filename} has been deleted."
    delete_file(file_path)
  else
    session[:error] = "#{filename} does not exist."
  end
  redirect '/'
end

post '/:filename/duplicate' do
  redirect_protected_content(session)
  filename = params[:filename]
  file_path = File.join(data_path, filename)
  extension = File.extname(filename)
  content = File.read(file_path)

  new_filename = filename.split('.').first + "-copy" + extension
  new_file_path = File.join(data_path, new_filename)

  if File.exist?(file_path)
    session[:success] = "'#{filename}' was copied to '#{new_filename}'"
    File.new(new_file_path,'w')
    write_contents_to_file(new_file_path, content)
  else
    session[:error] = "#{filename} does not exist."
  end
  redirect '/'
end

post '/create_document' do
  redirect_protected_content(session)
  filename = params[:filename]
  file_path = File.join(data_path, filename)
  
  redirect_if_invalid(filename, '/new')
  
  File.new(file_path,'w')
  session[:success] = "#{filename} has been created."
  redirect '/'
end

