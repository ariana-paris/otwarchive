require 'spec_helper'
require 'webmock'

# set up a valid token and some headers
def valid_headers
  api = ApiKey.first_or_create!(name: "Test", access_token: "testabc")
  {
    "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Token.encode_credentials(api.access_token),
    "HTTP_ACCEPT" => "application/json",
    "CONTENT_TYPE" => "application/json"
  }
end

# Let the test get at external sites, but stub out anything containing "foo" or "bar"
def mock_external
  WebMock.allow_net_connect!
  WebMock.stub_request(:any, /foo/).
    to_return(status: 200, body: "stubbed response", headers: {})
  WebMock.stub_request(:any, /bar/).
    to_return(status: 404, headers: {})
end

describe "API Authorization" do
  end_points = ["api/v1/import", "api/v1/works/import", "api/v1/bookmarks/import"]

  describe "API POST with invalid request" do
    it "should return 401 Unauthorized if no token is supplied" do
      end_points.each do |url|
        post url
        assert_equal 401, response.status
      end
    end

    it "should return 403 Forbidden if the specified user isn't an archivist" do
      end_points.each do |url|
        post url,
             { archivist: "mr_nobody" }.to_json,
             valid_headers
        assert_equal 403, response.status
      end
    end
  end
end

describe "API ImportController" do
  mock_external

  # Override is_archivist so all users are archivists from this point on
  class User < ActiveRecord::Base
    def is_archivist?
      true
    end
  end

  describe "API import with a valid archivist" do
    it "should return 200 OK when all stories are created" do
      user = create(:user)
      post "/api/v1/import",
           {archivist: user.login,
            works: [{external_author_name: "bar",
                     external_author_email: "bar@foo.com",
                     chapter_urls: ["http://foo"]}]
           }.to_json,
           valid_headers
      assert_equal 200, response.status
    end

    it "should return 200 OK when no stories are created" do
      user = create(:user)
      post "/api/v1/import",
           {archivist: user.login,
            works: [{external_author_name: "bar",
                     external_author_email: "bar@foo.com",
                     chapter_urls: ["http://bar"]}]
           }.to_json,
           valid_headers
      assert_equal 200, response.status
    end

    it "should return 200 OK when only some stories are created" do
      user = create(:user)
      post "/api/v1/import",
           {archivist: user.login,
            works: [{external_author_name: "bar",
                     external_author_email: "bar@foo.com",
                     chapter_urls: ["http://foo"]},
                    {external_author_name: "bar2",
                     external_author_email: "bar2@foo.com",
                     chapter_urls: ["http://foo"]}]
           }.to_json,
           valid_headers
      assert_equal 200, response.status
    end

    it "should return 400 Bad Request if no works are specified" do
      user = create(:user)
      post "/api/v1/import",
           {archivist: user.login}.to_json,
           valid_headers
      assert_equal 400, response.status
    end
  end

  WebMock.allow_net_connect!
end

describe "API BookmarksController" do
  mock_external

  # Override is_archivist so all users are archivists from this point on
  class User < ActiveRecord::Base
    def is_archivist?
      true
    end
  end

  external_work = {
    url: "http://foo.com",
    author: "Thing",
    title: "Title Thing",
    summary: "<p>blah blah blah</p>",
    fandom_string: "Testing",
    rating_string: "General Audiences",
    category_string: ["M/M"],
    relationship_string: "Starsky/Hutch",
    character_string: "Starsky,hutch"
  }

  bookmark = { pseud_id: "30805",
               external: external_work,
               notes: "<p>Notes</p>",
               tag_string: "youpi",
               collection_names: "",
               private: "0",
               rec: "0" }

  describe "API import with a valid archivist" do
    it "should return 200 OK when all bookmarks are created" do
      user = create(:user)
      post "/api/v1/bookmarks/import",
           { archivist: user.login,
             bookmarks: [ bookmark ]
           }.to_json,
           valid_headers
      assert_equal 200, response.status
    end

    it "should return 200 OK when no bookmarks are created" do
      user = create(:user)
      post "/api/v1/bookmarks/import",
           { archivist: user.login,
             bookmarks: [ bookmark ]
           }.to_json,
           valid_headers
      assert_equal 200, response.status
    end

    it "should return 200 OK when only some bookmarks are created" do
      user = create(:user)
      post "/api/v1/bookmarks/import",
           { archivist: user.login,
             bookmarks: [ bookmark, bookmark ]
           }.to_json,
           valid_headers
      assert_equal 200, response.status
    end

    it "should create bookmarks associated with the archivist" do
      user = create(:user)
      pseud_id = user.default_pseud.id
      post "/api/v1/bookmarks/import",
           { archivist: user.login,
             bookmarks: [ bookmark, bookmark ]
           }.to_json,
           valid_headers
      bookmarks = Bookmark.find_all_by_pseud_id(pseud_id)
      assert_equal bookmarks.count, 2
    end

    it "should return 400 Bad Request if an invalid URL is specified" do
      user = create(:user)
      post "/api/v1/import",
           { archivist: user.login,
             bookmarks: [ bookmark.merge!( { external: external_work.merge!( { url: "http://bar.com" })}) ] }.to_json,
           valid_headers
      assert_equal 400, response.status
    end

    it "should return 400 Bad Request if no bookmarks are specified" do
      user = create(:user)
      post "/api/v1/import",
           { archivist: user.login }.to_json,
           valid_headers
      assert_equal 400, response.status
    end
  end

  WebMock.allow_net_connect!
end

describe "API WorksController" do
  before do
    @work = FactoryGirl.create(:work, posted: true, imported_from_url: "foo")
  end

  describe "valid work URL request" do
    it "should return 200 OK" do
      post "/api/v1/works/urls",
           { original_urls: %w(bar foo) }.to_json,
           valid_headers
      assert_equal 200, response.status
    end

    it "should return the work URL for an imported work" do
      post "/api/v1/works/urls",
           { original_urls: %w(foo) }.to_json,
           valid_headers
      parsed_body = JSON.parse(response.body)
      expect(parsed_body.first["status"]).to eq "ok"
      expect(parsed_body.first["work_url"]).to eq work_url(@work)
      expect(parsed_body.first["created"]).to eq @work.created_at.as_json
    end

    it "should return an error for a work that wasn't imported" do
      post "/api/v1/works/urls",
           { original_urls: %w(bar) }.to_json,
           valid_headers
      parsed_body = JSON.parse(response.body)
      expect(parsed_body.first["status"]).to eq("not_found")
      expect(parsed_body.first).to include("error")
    end

    it "should only do an exact match on the original url" do
      post "/api/v1/works/urls",
           { original_urls: %w(fo food) }.to_json,
           valid_headers
      parsed_body = JSON.parse(response.body)
      expect(parsed_body.first["status"]).to eq("not_found")
      expect(parsed_body.first).to include("error")
      expect(parsed_body.second["status"]).to eq("not_found")
      expect(parsed_body.second).to include("error")
    end
  end
end
