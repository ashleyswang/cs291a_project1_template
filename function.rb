# frozen_string_literal: true

require 'json'
require 'jwt'
require 'pp'

def main(event:, context:)
  # You shouldn't need to use context, but its fields are explained here:
  # https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html

  path = event['path']
  method = event['httpMethod']

  if path != '/' && path != '/token'
    return response(status: 404)
  elsif path == '/'
    get_root(event)
  elsif path == '/token'
    post_token(event)
  else
    response(body: event, status: 200)
  end

end

def get_root(event) 
  # Check Token
  if event['httpMethod'] != 'GET'
    return response(status: 405)
  elsif !event.key?('headers') || !event['headers'].key?('Authorization')
    return response(status: 403)
  end
end

def post_token(event)  
  # Check HTTP method and content type
  if event['httpMethod'] != 'POST'
    return response(status: 405)
  elsif event['headers'].key?('Content-Type') && 
    event['headers']['Content-Type'] != 'application/json'
    return response(status: 415)
  end

  # Create payload for response
  begin
    body = JSON.parse(event['body'])
    payload = {
      data: body,
      exp: Time.now.to_i + 5,
      nbf: Time.now.to_i + 2
    }
    token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
    return response(body: { token: token }, status: 201)

  rescue JSON::ParserError => e
    return response(body: nil, status: 422)
  end
end

def response(body: nil, status: 200)
  {
    body: body ? body.to_json + "\n" : '',
    statusCode: status
  }
end

if $PROGRAM_NAME == __FILE__
  # If you run this file directly via `ruby function.rb` the following code
  # will execute. You can use the code below to help you test your functions
  # without needing to deploy first.
  ENV['JWT_SECRET'] = 'NOTASECRET'

  # Call /token
  PP.pp main(context: {}, event: {
               'body' => '{"name": "bboe"}',
               'headers' => { 'Content-Type' => 'application/json' },
               'httpMethod' => 'POST',
               'path' => '/token'
             })

  # Generate a token
  payload = {
    data: { user_id: 128 },
    exp: Time.now.to_i + 1,
    nbf: Time.now.to_i
  }
  token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
  # Call /
  PP.pp main(context: {}, event: {
               'headers' => { 'Authorization' => "Bearer #{token}",
                              'Content-Type' => 'application/json' },
               'httpMethod' => 'GET',
               'path' => '/'
             })
end
