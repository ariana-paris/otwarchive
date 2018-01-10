# frozen_string_literal: true
require "spec_helper"
require "api/api_helper"

include ApiHelper

def post_search_result(valid_params)
  post "/api/v2/works/search", params: valid_params.to_json, headers: valid_headers
  JSON.parse(response.body, symbolize_names: true)
end

describe "v2 API work search with URLs" do
  work = FactoryGirl.create(:work, posted: true, imported_from_url: "foo")
  
  it "returns 200 OK" do
    valid_params = { works: [{ original_urls: [{url: "bar"}, {url: "foo"}] }] }
    post "/api/v2/works/search", params: valid_params.to_json, headers: valid_headers

    assert_equal 200, response.status
  end

  it "returns the work URL for an imported work" do
    valid_params = { works: [{ original_urls: [{url: "foo"}] }] }
    parsed_body = post_search_result(valid_params)
    search_results = parsed_body[:works].first[:search_results]

    expect(parsed_body[:works].first[:status]).to eq "found"
    expect(search_results).to include(include(archive_url: work_url(work)))
    expect(search_results.any? { |w| w[:created].to_date == work.created_at.to_date }).to be_truthy
  end

  it "returns the original reference if one was provided" do
    valid_params = { works: [{ id: 123, original_urls: [{ url: "foo" }] }] }
    parsed_body = post_search_result(valid_params)
    
    expect(parsed_body[:works].first[:status]).to eq "found"
    expect(parsed_body[:works].first[:original_search][:id]).to eq 123
    expect(parsed_body[:works].first[:original_search][:original_urls].first[:url]).to eq "foo"
  end

  it "returns an error when no works are provided" do
    invalid_params = { works: [] }
    parsed_body = post_search_result(invalid_params)
    
    expect(parsed_body[:messages].first).to eq "Please provide a list of works to find."
  end
  
  it "returns an error when too many works are provided" do
    loads_of_items = Array.new(210) { |_| { original_urls: [{url: "url"}] } }
    valid_params = { works: loads_of_items }
    parsed_body = post_search_result(valid_params)

    expect(parsed_body[:messages].first).to start_with "Please provide no more than"
  end

  it "returns a not found message for a work that wasn't found" do
    valid_params = { works: [{ original_urls: [{url: "bar"}] }] }
    parsed_body = post_search_result(valid_params)
    
    expect(parsed_body[:works].first[:status]).to eq("not_found")
    expect(parsed_body[:works].first).to include(:messages)
  end

  it "should only do an exact match on the original url" do
    valid_params = { works: [{ original_urls: [{url: "fo"}] }, { original_urls: [{url: "food"}] }] }
    parsed_body = post_search_result(valid_params)

    expect(parsed_body[:works].first[:status]).to eq("not_found")
    expect(parsed_body[:works].first).to include(:messages)
    expect(parsed_body[:works].second[:status]).to eq("not_found")
    expect(parsed_body[:works].second).to include(:messages)
  end
end


describe "v2 API full work search" do
  # Searches
  search_found_title = { title: api_fields[:title] }
  search_found_pseud = { title: api_fields[:title], creators: "Bar", fandom: "Testing" }
  search_found_login = { id: "789", title: api_fields[:title] + " Two", creators: "foo", fandom: "Testing" }
  search_not_found = { id: "435", title: "Not found", creators: "Foo", fandom: "Testing" }

  before(:each) do
    works.each(&:save)
    update_and_refresh_indexes("work")
  end
  
  after :all do
    Work.destroy_all
    delete_index "work"
  end
  
  # Works
  let!(:users) {
    user = User.find_by(login: "foo")
    user2 = User.find_by(login: "bar")
    user ||= create(:user, login: "foo")
    user2 ||= create(:user, login: "bar")
    [user, user2]
  }
  let!(:pseud) { create(:pseud, name: "Bar", user_id: users.first.id) }
  let(:works) {
    w1 = create(:posted_work, title: api_fields[:title], authors: [pseud])
    w2 = create(:posted_work, title: api_fields[:title] + " Two", authors: [users.second.default_pseud])
    w3 = create(:posted_work, title: api_fields[:title])
    w4 = create(:posted_work, title: "Something completely different")
    update_and_refresh_indexes("work")
    [w1, w2, w3, w4]
  }
  
  context "searching for a non-existent work" do
    let!(:result) { post_search_result(works: [search_not_found]) }
    
    it "responds with a 200 OK" do
      assert_equal "ok", result[:status]
    end
    
    it "returns the original search query" do
      result_search = result[:works].first[:original_search]
      expect(result_search).to eq(search_not_found)
    end
    
    it "returns an empty result" do
      expect(result.key?(:search_results)).to be_falsey
    end
  end
  
  context "searching for existing works" do
    let!(:result) { post_search_result(works: [search_found_title, search_found_login, search_found_pseud]) }

    it "responds with a 200 OK" do
      result = post_search_result(works: [search_found_title])
      assert_equal 200, response.status
      assert_equal "ok", result[:status]
    end
    
    it "returns the original search query" do
      result = post_search_result(works: [search_found_title])
      expect(result[:works].first[:original_search]).to eq(search_found_title)
    end
    
    it "matches works by matching title words ('api', 'title')" do
      result = post_search_result(works: [search_found_title])[:works].first
      assert_equal 3, result[:search_results].size 
      expect(result[:works].first[:search_results]).to_not be_empty 
    end

    it "returns all works that match a partial title" do
      result = post_search_result(works: [ { title: "Title" }])[:works].first
      result[:search_results].size.should be > 1
      result[:search_results].first[:archive_url].should_not be_nil
    end
    
    it "matches an exact pseud" do
      result = post_search_result(works: [search_found_pseud])[:works].first
      assert_equal search_found_pseud, result[:original_search]
      assert_equal 1, result[:search_results].size
      result[:search_results].first[:archive_url].should_not be_nil
    end
    
    it "matches an exact login" do
      result = post_search_result(works: [search_found_login])[:works].first
      assert_equal search_found_login, result[:original_search]
      assert_equal 1, result[:search_results].size
      result[:search_results].first[:archive_url].should_not be_nil
    end
  end
  
end


describe "v2 API work search without URLs" do
 
  context "not found work" do

    after :all do
      clean_the_database
    end
  
    it "takes a batch of work fields and returns works" do
      post_search_result(valid_input)
      assert_equal 200, response.status
    end

    it "returns the original id if one was provided" do
      
    end

    it "returns the work's details if a work with a matching title and pseud is found" do
      expect(@first_result[:search_results].first[:archive_url]).to_not be_empty
    end

    it "returns the work's details if a work with a matching title and pseud is found" do
      expect(@third_result[:search_results].first[:archive_url]).to_not be_empty
    end
    
    it "returns an empty result if no matching works are found" do
      
    end
  end

  it "should match works on parent fandom" do

  end

  it "should complain if it doesn't have all the fields" do

  end

end
