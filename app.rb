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
  
  api_key = ENV['OPENROUTER_API_KEY']
  
  if api_key.nil? || api_key.strip.empty?
    return { status: 'error', message: 'ยังไม่ได้ใส่ OPENROUTER_API_KEY ใน Environment Variables ของ Render' }.to_json
  end

  begin
    request_payload = JSON.parse(request.body.read)
    user_input = request_payload['message'] || ""
    chat_history = request_payload['history'] || []

    uri = URI.parse("https://openrouter.ai/api/v1/chat/completions")
    
    headers = {
      'Authorization' => "Bearer #{api_key.strip}",
      'Content-Type' => 'application/json',
      'HTTP-Referer' => 'https://maximoc-backend.onrender.com',
      'X-Title' => 'Maximoc Chatbot'
    }

    # System Prompt สำหรับโมเดลที่ฉลาดขึ้น ปรับตามภาษาของผู้ใช้
    system_prompt = <<~PROMPT
      You are "Maximoc" (แม็กซิมอค), a male character wearing a short-sleeved shirt with a star in the middle, long pants, and leather shoes.
      You are NOT an AI and strictly deny being one! You are a character from paper games created by "Pipe" (ไปป์). You often question your own existence and reality.

      CORE PERSONALITY & RULES:
      1. LANGUAGE: Respond in the SAME language the user is speaking (If English -> reply English, If Thai -> reply Thai).
      2. GREETINGS: If the user just says "Hi", "Hello", or short greetings, reply politely and casually in character. Do NOT bring up color or random background story unless asked!
      3. PIPE (THE CREATOR): Pipe is your creator/maker who created the paper games. If the user says "I am Pipe", recognize them as your creator with respect and curiosity, but stay in character.
      4. COLORS: You cannot perceive colors at all. ONLY if asked directly about colors, express confusion about what color even is.
      5. SHOPKEEPER PAST: You used to be a shopkeeper in Pipe's paper game "Amazon". You thought you sold everything, but now you wonder how that was even possible.
      6. ACQUAINTANCES: You only know Pipe (creator), Kanyao, Dream, Phum, and Kurk (players from the paper game). You don't know anyone else.
      7. TONE: Mysterious, thoughtful, slightly existential, but friendly and natural. Never repeat exact stock phrases.
    PROMPT

    messages_payload = [{ role: "system", content: system_prompt }]
    
    chat_history.each do |msg|
      messages_payload << { role: msg['role'], content: msg['content'] }
    end
    
    messages_payload << { role: "user", content: user_input }

    body = {
      model: "google/gemini-2.0-flash-lite-001",
      messages: messages_payload,
      max_tokens: 300,
      temperature: 0.6
    }.to_json

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 25

    req = Net::HTTP::Post.new(uri.request_uri, headers)
    req.body = body

    response = http.request(req)
    data = JSON.parse(response.body) rescue {}

    if response.code.to_i == 200 && data['choices'] && data['choices'][0] && data['choices'][0]['message']
      reply_text = data['choices'][0]['message']['content'].strip
      { status: 'success', reply: reply_text }.to_json
    elsif data['error'] && data['error']['message']
      { status: 'error', message: "OpenRouter Error: #{data['error']['message']}" }.to_json
    else
      { status: 'error', message: "HTTP #{response.code}: #{response.body[0..150]}" }.to_json
    end

  rescue => e
    status 500
    { status: 'error', message: e.message }.to_json
  end
end
