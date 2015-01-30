require 'spec_helper'

describe 'API response codes' do

  it 'should be 200 when client has an authentication token' do
    @api = ApiKey.create!(name: 'Test', access_token: 'testabc')
    get '/api/v1/works', nil,
        { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Token.encode_credentials(@api.access_token),
          'HTTP_ACCEPT' => 'application/json'
        }
    assert_equal 200, response.status
  end

  it 'should return 401 when client has no token' do
    get '/api/v1/works'
    assert_equal 401, response.status
  end

end