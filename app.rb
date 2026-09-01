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

# สร้าง instance ของ CleverBot
bot = CleverBot.new

post '/chat' do
  content_type :json
  
  begin
    request_payload = JSON.parse(request.body.read)
    user_input = request_payload['message']

    # ส่งคำถามไปยัง Cleverbot
    reply = bot.think(user_input)

    if reply && !reply.empty?
      { status: 'success', reply: reply }.to_json
    else
      # กรณี Cleverbot คืนค่าว่างเปล่า
      { status: 'error', message: 'Cleverbot returned empty response' }.to_json
    end
  rescue => e
    # ส่งข้อความ Error ที่เกิดขึ้นจริงกลับไปแสดงผล
    puts "Error during chat: #{e.message}"
    status 500
    { status: 'error', message: e.message }.to_json
  end
end
