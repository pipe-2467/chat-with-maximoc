require 'sinatra'
require 'net/http'
require 'uri'
require 'json'

set :bind, '0.0.0.0'
set :port, ENV['PORT'] || 4567

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
end

options '*' do
  200
end

post '/chat' do
  content_type :json
  
  begin
    request_payload = JSON.parse(request.body.read)
    user_input = request_payload['message'] || ""

    # ยิงผ่าน Free AI API (Pollinations)
    prompt = "You are Maximoc, a clever and friendly AI chatbot. Answer concisely to this message: #{user_input}"
    encoded_prompt = URI.encode_www_form_component(prompt)
    
    uri = URI.parse("https://text.pollinations.ai/#{encoded_prompt}")
    response = Net::HTTP.get_response(uri)

    reply_text = response.body.force_encoding("UTF-8").strip

    { status: 'success', reply: reply_text }.to_json
  rescue => e
    status 500
    { status: 'error', message: e.message }.to_json
  end
end
