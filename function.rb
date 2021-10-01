# frozen_string_literal: true

require 'json'
require 'jwt'
require 'pp'

def main(event:, context:)
  # You shouldn't need to use context, but its fields are explained here:
  # https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html

  # return error 404 if request to any other resource
  if event['path'] != '/' and event['path'] != '/token'
    return response(body: nil, status: 404)
  end

  # return error 405 if request doesn't use Http method: GET and POST
  if (event['path'] == '/' and event['httpMethod'] != 'GET') or (event['path'] == '/token' and event['httpMethod'] != 'POST')
    return response(body: nil, status: 405)
  end

  # print('ENTERED')
  
  #GET
  #if event['httpMethod'] == 'GET'
   # if !event['headers'].key?('Authorization')
    #  return response(body: nil, status: 403)
   # end

    #begin
     # token = JWT.decode event["headers"]["Authorization"][7..-1], ENV["JWT_SECRET"], true, { algorithm: 'HS256' }
      #return response(body: token[0]['data'], status: 200)
    #rescue JWT::ImmatureSignature, JWT::ExpiredSignature => e
     # return response(body: nil, status: 401)
    #rescue JWT::DecodeError => e
     # return response(body: nil, status: 403)
    #end
  #end
  
  if event['httpMethod'] == 'GET'
    #found = false
    event['headers'].each do |key, val|
      if key.downcase == 'authorization'
        # Authorization => Bearer #{token}
        auth_token = val.split(' ')
        #break if authToken.count != 2
        #break if authToken[0] != 'Bearer'
        # check format of header
        if auth_token[0] != 'Bearer' or auth_token.count != 2
          return response(body: nil, status: 403)
        end
        token = auth_token[1]
        decoded_token = ''
        begin
          decoded_token = JWT.decode token, ENV['JWT_SECRET'], true, { algorithm: 'HS256' }
        rescue JWT::ImmatureSignature, JWT::ExpiredSignature => e
          return response(body: nil, status: 401)
        rescue JWT::DecodeError => e
          return response(body: e, status: 403)
        end
        #found = true
        json_data = decoded_token[0]['data']
        return response(body: json_data, status: 200)
      end
    end
    return response(body: nil, status: 403)
  end

  # POST
  if event['httpMethod'] == 'POST'

    # return error 415 if not JSON
    event['headers'].each do |key, val|
      if key.downcase == "content-type" and val != 'application/json'
        return response(body: nil, status: 415)
      end
    end

    # return error 422 if body not JSON
    # check if body is empty
    if event['body'] == '' or event['body'] == nil
      return response(body: nil, status: 422)
    end
    begin
      json_data = JSON.parse(event['body'])
    rescue JSON::ParserError => e
      return response(body: nil, status: 422)
    end

    payload = {
      data: json_data,
      exp: Time.now.to_i + 1,
      nbf: Time.now.to_i
    }

    token = JWT.encode(payload, ENV['JWT_SECRET'], 'HS256')
    return response(body: { 'token' => token }, status: 201)
  end
  
  response(body: event, status: 422)
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