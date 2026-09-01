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

bot = nil
begin
  bot = CleverBot.new
rescue => e
  puts "CleverBot init error: #{e.message}"
end

post '/chat' do
  content_type :json
  
  begin
    request_payload = JSON.parse(request.body.read)
    user_input = request_payload['message'] || ""

    reply_text = nil

    # ลองใช้ CleverBot หากเชื่อมต่อได้
    if bot
      begin
        reply_text = bot.think(user_input)
      rescue => e
        puts "Bot think error: #{e.message}"
      end
    end

    # หาก CleverBot API เก่าตอบกลับไม่ได้ ให้ใช้ระบบตอบกลับสำรองของ Maximoc
    if reply_text.nil? || reply_text.strip.empty?
      responses = [
        "That's interesting! Tell me more about #{user_input}.",
        "I am Maximoc! I hear you saying: '#{user_input}'.",
        "Why do you think that?",
        "That's a very cool perspective!",
        "Maximoc is thinking deeply about this..."
      ]
      reply_text = responses.sample
    end

    { status: 'success', reply: reply_text }.to_json

  rescue => e
    status 500
    { status: 'error', message: e.message }.to_json
  end
end
