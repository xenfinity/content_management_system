  # def test_sign_up_valid_credentials
  #   username = "test_new_user"
  #   password = "Password1"

  #   get "/users/signup"
  #   assert_equal 200, last_response.status

  #   post "/users/signup", username: username, password: password
  #   assert_equal 302, last_response.status
  #   assert_equal "#{username} successfully signed up! Please sign in below", session[:success]

  #   users_path = File.join(test_path, "users.yml")
  #   assert_includes File.read(users_path), username
  # end

  # def test_sign_up_invalid_password_length
  #   username = "test_new_user"
  #   password = "Pwd1234"

  #   get "/users/signup"
  #   assert_equal 200, last_response.status

  #   post "/users/signup", username: username, password: password
  #   assert_equal 302, last_response.status
  #   assert_equal "Password is too short, must be at least 8 characters long.", session[:error]

  #   users_path = File.join(test_path, "users.yml")
  #   refute_includes File.read(users_path), username
  # end

  # def test_sign_up_invalid_username_length
  #   username = "me"
  #   password = "Password1"

  #   get "/users/signup"
  #   assert_equal 200, last_response.status

  #   post "/users/signup", username: username, password: password
  #   assert_equal 302, last_response.status
  #   assert_equal "Username is too short, must be at least 3 characters long.", session[:error]

  #   users_path = File.join(test_path, "users.yml")
  #   refute_includes File.read(users_path), username
  # end