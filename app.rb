require 'sinatra'
require 'cleverbot-api'
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

bot = Cleverbot.new

post '/chat' do
  content_type :json
  payload = JSON.parse(request.body.read)
  user_input = payload['message']

  begin
    reply = bot.think(user_input)
    { status: 'success', reply: reply }.to_json
  rescue => e
    status 500
    { status: 'error', message: e.message }.to_json
  end
end
