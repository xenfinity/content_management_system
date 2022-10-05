ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "yaml"

require_relative "cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    @filenames = ["about.txt", "about.md"]
    
    FileUtils.mkdir_p(data_path)
    @filenames.each do |filename|
      file_path = File.join(data_path, filename)
      content = case File.extname(filename)
                when '.txt'
                   "this is text content"
                when '.md'
                   "#this is a header"
                end
      create_document(content, file_path)
    end
    create_users_file
  end

  def create_users_file
    file_path = File.join(test_path, "users.yml")
    content = "{ test_admin: $2a$12$8Pchx0QUvyvhgQi6SeRqnuEDzMsVOrOw6IL6MVAMIDsmH/.V02wnO }"
    create_document(content, file_path)
  end

  def test_path
    File.expand_path("../test", __FILE__)
  end
  def teardown
    FileUtils.rm_rf(data_path)
  end

  # test/cms_test.rb
  def create_document(content = "", file_path)
    write_contents_to_file(file_path, content)
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    {"rack.session" => { username: "admin", signed_in: true } }
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    @filenames.each do |filename|
      assert_includes last_response.body, filename
    end
  end

  def test_file_does_not_exist
    filename = "notafile.ext"
    get "/#{filename}"
    assert_equal 302, last_response.status
    assert_equal "#{filename} does not exist.", session[:error]

    get last_response["Location"]
    assert_equal 200, last_response.status
  end
  
  def test_text_files
    @filenames.each do |filename|
      next unless filename.split('.').last == "txt"
      get "/#{filename}"
      assert_equal 200, last_response.status
      assert_equal "text/plain", last_response["Content-Type"]
      assert_includes last_response.body, "this is text content"
    end
  end

  def test_markdown_files
    @filenames.each do |filename|
      next unless filename.split('.').last == "md"
      get "/#{filename}"
      assert_equal 200, last_response.status
      assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
      assert_includes last_response.body, "<h1>this is a header</h1>"
    end
  end

  def test_edit_page
    @filenames.each do |filename|
      get "/#{filename}/edit", {}, admin_session
      assert_equal 200, last_response.status
      assert_includes last_response.body, File.read("#{data_path}/#{filename}") 
    end
  end

  def test_write_to_file
    @filenames.each do |filename|
      new_content = "new content"

      post "/#{filename}/write", {content: new_content, new_filename: filename}, admin_session
      assert_equal 302, last_response.status
      assert_equal "#{filename} has been updated.", session[:success]

      get "/#{filename}"
      assert_equal 200, last_response.status
      
      assert_includes File.read("#{data_path}/#{filename}"), "new content"
    end
  end

  def test_rename_file
    @filenames.each do |filename|
      new_content = "new content"
      new_filename = "new_filename.txt"
      file_path = File.join(data_path, filename)
      new_file_path = File.join(data_path, new_filename)

      post "/#{filename}/write", {content: new_content, new_filename: new_filename}, admin_session
      assert_equal 302, last_response.status
      assert_equal "#{filename} was renamed to #{new_filename}", session[:success]

      get "/#{new_filename}"
      assert_equal 200, last_response.status

      assert_equal true, File.exist?(new_file_path)
      assert_equal false, File.exist?(file_path)
    end
  end

  def test_create_file
    filename = "newfile.txt"

    get "/new", {}, admin_session
    assert_equal 200, last_response.status

    post "/create_document", filename: filename
    assert_equal 302, last_response.status
    assert_equal "#{filename} has been created.", session[:success]

    File.exist?("#{data_path}/#{filename}")
  end 

  def test_attempt_create_empty_file
    filename = ""

    get "/new", {}, admin_session
    assert_equal 200, last_response.status

    post "/create_document", filename: filename
    assert_equal 302, last_response.status
    assert_equal "A file name is required", session[:error]
  end 

  def test_attempt_create_file_no_extension
    filename = "filename"

    get "/new", {}, admin_session
    assert_equal 200, last_response.status

    post "/create_document", filename: filename
    assert_equal 302, last_response.status
    assert_equal "A file extension is required (e.g. '.txt', '.md')", session[:error]
  end 

  def test_attempt_create_file_invalid_extension
    filename = "filename.doc"

    get "/new", {}, admin_session
    assert_equal 200, last_response.status

    post "/create_document", {filename: filename}
    assert_equal 302, last_response.status
    assert_equal "Invalid file extension - Valid extensions: .txt, .md", session[:error]
  end 

  def test_delete_file
    filename = "about.md"

    post "/#{filename}/delete", {}, admin_session 
    assert_equal 302, last_response.status
    assert_equal "about.md has been deleted.", session[:success]

    get "/"
    refute_includes last_response.body, "test.txt"
  end

  def test_duplicate_file
    filename = "about.md"
    file_path = File.join(data_path, filename)
    new_filename = "about-copy.md"
    new_file_path = File.join(data_path, new_filename)

    post "/#{filename}/duplicate", {}, admin_session 
    assert_equal 302, last_response.status
    assert_equal "'about.md' was copied to 'about-copy.md'", session[:success]

    get last_response["Location"]
    assert_includes last_response.body, "about-copy.md"

    assert_equal File.read(file_path), File.read(new_file_path)
  end

  def test_sign_up_valid_credentials
    username = "test_new_user"
    password = "Password1"

    get "/users/signup"
    assert_equal 200, last_response.status

    post "/users/signup", username: username, password: password
    assert_equal 302, last_response.status
    assert_equal "#{username} successfully signed up! Please sign in below", session[:success]

    users_path = File.join(test_path, "users.yml")
    assert_includes File.read(users_path), username
  end

  def test_sign_up_invalid_password_length
    username = "test_new_user"
    password = "Pwd1234"

    get "/users/signup"
    assert_equal 200, last_response.status

    post "/users/signup", username: username, password: password
    assert_equal 302, last_response.status
    assert_equal "Password is too short, must be at least 8 characters long.", session[:error]

    users_path = File.join(test_path, "users.yml")
    refute_includes File.read(users_path), username
  end

  def test_sign_up_invalid_password_no_number
    username = "test_new_user"
    password = "Password"

    get "/users/signup"
    assert_equal 200, last_response.status

    post "/users/signup", username: username, password: password
    assert_equal 302, last_response.status
    assert_equal "Password must contain at least one uppercase letter, lowercase letter and number", session[:error]

    users_path = File.join(test_path, "users.yml")
    refute_includes File.read(users_path), username
  end

  def test_sign_up_invalid_password_no_uppercase
    username = "test_new_user"
    password = "password1"

    get "/users/signup"
    assert_equal 200, last_response.status

    post "/users/signup", username: username, password: password
    assert_equal 302, last_response.status
    assert_equal "Password must contain at least one uppercase letter, lowercase letter and number", session[:error]

    users_path = File.join(test_path, "users.yml")
    refute_includes File.read(users_path), username
  end

  def test_sign_up_invalid_password_no_lowercase
    username = "test_new_user"
    password = "PASSWORD1"

    get "/users/signup"
    assert_equal 200, last_response.status

    post "/users/signup", username: username, password: password
    assert_equal 302, last_response.status
    assert_equal "Password must contain at least one uppercase letter, lowercase letter and number", session[:error]

    users_path = File.join(test_path, "users.yml")
    refute_includes File.read(users_path), username
  end

  def test_sign_up_invalid_username_length
    username = "me"
    password = "Password1"

    get "/users/signup"
    assert_equal 200, last_response.status

    post "/users/signup", username: username, password: password
    assert_equal 302, last_response.status
    assert_equal "Username is too short, must be at least 3 characters long.", session[:error]

    users_path = File.join(test_path, "users.yml")
    refute_includes File.read(users_path), username
  end

  def test_sign_up_username_exists
    username = "test_admin"
    password = "Password1"
    users = load_user_credentials
    users_path = File.join(test_path, "users.yml")
    users_content = File.read(users_path)

    get "/users/signup"
    assert_equal 200, last_response.status

    post "/users/signup", username: username, password: password
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Username already exists."

    assert_equal File.read(users_path), users_content
  end

  def test_successful_sign_in
    username = "test_admin"
    password = "password"

    get "/users/signin"
    assert_equal 200, last_response.status

    post "/users/signin", username: username, password: password
    assert_equal 302, last_response.status
    assert_equal "test_admin", session[:username]
    assert_equal true, session[:signed_in]
  end

  def test_bad_username
    username = "bad_username"
    password = "password"

    get "/users/signin"
    assert_equal 200, last_response.status

    post "/users/signin", username: username, password: password
    assert_equal 302, last_response.status
    refute_equal "admin", session[:username]
    refute_equal true, session[:signed_in]
  end

  def test_bad_password
    username = "test_admin"
    password = "bad_password"

    get "/users/signin"
    assert_equal 200, last_response.status

    post "/users/signin", username: username, password: password
    assert_equal 302, last_response.status
    refute_equal "admin", session[:username]
    refute_equal true, session[:signed_in]
  end

  def test_signout
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal "Successfully signed out", session[:success]
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_nil session[:username]
    refute_equal true, session[:signed_in]
  end

  def test_signed_out_edit_page
    get "/about.md/edit"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end

  def test_signed_out_write
    post "/about.md/write", content: "new content"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end

  def test_signed_out_new_page
    get "/new"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end

  def test_signed_out_create
    post "/create_document", filename: "new_file.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end

  def test_signed_out_delete
    post "/about.md/delete"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end
end