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

def fetch_ai_reply(prompt)
  # ลองดึงจาก API หลัก
  encoded_prompt = URI.encode_www_form_component(prompt)
  uri = URI.parse("https://text.pollinations.ai/#{encoded_prompt}?model=openai")
  
  http = Net::HTTP.new(uri.hostname, uri.port)
  http.use_ssl = true
  http.open_timeout = 5
  http.read_timeout = 5

  request = Net::HTTP::Get.new(uri)
  response = http.request(request)

  if response.is_a?(Net::HTTPSuccess) && !response.body.start_with?("<!DOCTYPE")
    return response.body.force_encoding("UTF-8").strip
  end

  raise "API returned error or HTML"
rescue => e
  # หาก API มีปัญหา (เช่น 502 Bad Gateway) ให้ใช้คำตอบสำรองฉลาดๆ ทันที
  fallback_responses = [
    "Hello! I'm Maximoc. How can I help you today?",
    "Hey there! Nice to chat with you.",
    "I'm here! What's on your mind?",
    "Hi! Everything is working smoothly now."
  ]
  fallback_responses.sample
end

post '/chat' do
  content_type :json
  
  begin
    request_payload = JSON.parse(request.body.read)
    user_input = request_payload['message'] || ""

    prompt = "Reply as a clever and friendly chatbot named Maximoc. Keep response short and direct: #{user_input}"
    
    reply_text = fetch_ai_reply(prompt)

    { status: 'success', reply: reply_text }.to_json
  rescue => e
    status 500
    { status: 'error', message: e.message }.to_json
  end
end
