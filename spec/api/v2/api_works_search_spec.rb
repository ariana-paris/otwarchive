# frozen_string_literal: true
require "spec_helper"
require "api/api_helper"

include ApiHelper

def post_search_result(valid_params)
  post "/api/v2/works/search", params: valid_params.to_json, headers: valid_headers
  JSON.parse(response.body, symbolize_names: true)
end

describe "v2 Search with valid work URL request" do
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
    search_results = parsed_body[:works].first[:search_results]
    
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

describe "v2 API work search without URLs" do
  valid_input = 
    { works: [{ title: api_fields[:title], creator: "Bar", fandom: "Testing"},
              { id: "435", title: "Not found", creator: "Foo", fandom: "Testing"}] }
  
  context "given a valid request" do

    before :all do
      create(:work, title: api_fields[:title])
      @parsed_body = post_search_result(valid_input)
    end
  
    it "performs a full search when no URLs are provided" do
      invalid_params = { works: [{ title: "Title", original_urls: [] }] }
      parsed_body = post_search_result(invalid_params)
  
      expect(parsed_body[:messages].first).to eq "No works match title: \"Title\", author: \"."
    end
  
    it "takes a batch of work fields and returns works" do
      post_search_result(valid_input)
      assert_equal 200, response.status
    end

    it "returns the original id" do
      expect(@parsed_body[:works].second[:original_search][:id]).to eq("435")
    end

    it "returns a work URL if a matching works is found" do
      expect(@parsed_body[:works].first[:search_results].first[:archive_url]).to_not be_empty
    end
    
    it "returns an empty result if no matching works are found" do
      expect(@parsed_body[:works].second.key?(:search_results)).to be_falsey
    end
  end

  it "should match works on parent fandom" do

  end

  it "should complain if it doesn't have all the fields" do

  end

end
