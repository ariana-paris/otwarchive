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
    valid_params = { works: [{ original_urls: %w(bar foo) }] }
    post "/api/v2/works/search", params: valid_params.to_json, headers: valid_headers

    assert_equal 200, response.status
  end

  it "returns the work URL for an imported work" do
    valid_params = { works: [{ original_urls: %w(foo) }] }
    parsed_body = post_search_result(valid_params)
    search_results = parsed_body[:works].first[:search_results]

    expect(parsed_body[:works].first[:status]).to eq "found"
    expect(search_results).to include(include(archive_url: work_url(work)))
    expect(search_results.any? { |w| w[:created].to_date == work.created_at.to_date }).to be_truthy
  end

  it "returns the original reference if one was provided" do
    valid_params = { works: [{ original_urls: [{ id: "123", url: "foo" }] }] }
    parsed_body = post_search_result(valid_params)

    expect(parsed_body[:works].first[:status]).to eq "found"
    expect(parsed_body[:works].first[:original_id]).to eq "123"
    expect(parsed_body[:works].first[:original_url]).to eq "foo"
  end

  it "returns an error when no works are provided" do
    invalid_params = { works: [] }
    parsed_body = post_search_result(invalid_params)
    
    puts parsed_body.inspect

    expect(parsed_body[:messages].first).to eq "Please provide a list of works to find."
  end
  
  it "returns an error when too many works are provided" do
    loads_of_items = Array.new(210) { |_| { original_urls: ["url"] } }
    valid_params = { works: loads_of_items }
    parsed_body = post_search_result(valid_params)

    expect(parsed_body[:messages].first).to start_with "Please provide no more than"
  end
  
  it "returns an error when too many URLs are provided" do
    loads_of_items = Array.new(210) { |_| "url" }
    valid_params = { works: [{ original_urls: loads_of_items }] }
    parsed_body = post_search_result(valid_params)

    expect(parsed_body[:messages].first).to start_with "Please provide no more than"
  end

  it "returns a not found message for a work that wasn't found" do
    valid_params = { works: [{ original_urls: %w(bar) }] }
    parsed_body = post_search_result(valid_params)
    
    expect(parsed_body[:works].first[:status]).to eq("not_found")
    expect(parsed_body[:works].first).to include(:messages)
  end

  it "should only do an exact match on the original url" do
    valid_params = { works: [{ original_urls: %w(fo food) }] }
    parsed_body = post_search_result(valid_params)

    expect(parsed_body[:works].first[:status]).to eq("not_found")
    expect(parsed_body[:works].first).to include(:messages)
    expect(parsed_body[:works].second[:status]).to eq("not_found")
    expect(parsed_body[:works].second).to include(:messages)
  end
end

describe "v2 API work search without URLs" do
  it "performs a full search when no URLs are provided" do
    invalid_params = { works: [{ original_urls: [] }] }
    parsed_body = post_search_result(invalid_params)

    expect(parsed_body[:messages].first).to eq "Please provide a list of URLs to find."
  end
end

describe "v2 API Work Search" do
  valid_input =  
    { works: [{ title: api_fields["Title"], creator: "Bar", fandom: "Testing"},
              { original_url: "435", title: api_fields["Title"], creator: "Foo", fandom: "Testing"}] }

  output = { works: [{ original_url: "123",
                                works: [{ ao3_url: "works/12435", title: "Title", creator: "Author", fandom: "Testing" }]},
                              { original_url: "435",
                                works: []}]}

  it "should take a batch of work fields and return works" do
    puts valid_input
    post_search_result(valid_input)
    assert_equal 200, response.status
  end

  describe "given a valid request" do

    before :all do
      parsed_body = post_search_result(valid_input)
      @search_results = parsed_body[:search_results]
    end

    it "should return the original id" do
      expect(@search_results.first[:original_id]).to eq("123")
    end

    it "should return an empty result if no matching works are found" do
      expect(@search_results.second[:works]).to be_empty
    end
  end

  it "should match works on parent fandom" do

  end

  it "should complain if it doesn't have all the fields" do

  end

end
