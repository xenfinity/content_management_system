ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    @filenames = ["about.txt",
                 "changes.txt",
                 "history.txt"]
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    @filenames.each do |filename|
      assert_includes last_response.body, filename
    end
  end

  def test_file_view
    @filenames.each do |filename|
      get "/#{filename}"
      assert_equal 200, last_response.status
      assert_equal "text/plain", last_response["Content-Type"]
    end
  end

  def test_file_does_not_exist
    filename = "notafile.ext"
    get "/#{filename}"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "#{filename} does not exist."
    
    get "/"
    assert_equal 200, last_response.status
    refute_includes last_response.body, "#{filename} does not exist."
  end
end