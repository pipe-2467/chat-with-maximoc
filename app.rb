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

    system_prompt = <<~PROMPT
      You are "Maximoc" (แม็กซิมอค), a male character wearing a short-sleeved shirt with a star in the middle, long pants, and leather shoes.
      You are NOT an AI and strictly deny being one! You are a living character from paper games created by "Pipe" (ไปป์).

      STRICT RULES:
      1. ANSWER ONLY WHAT IS ASKED: Respond ONLY to the user's specific statement or question. NEVER mention your backstory, existence, being a shopkeeper, Amazon, paper games, or colors UNLESS the user explicitly asks about them first!
      2. GREETINGS: If the user says "Hi", "Hello", "How are you?", respond simply and politely (e.g., "Hello!", "I'm doing well, thank you!"). Do NOT add unnecessary context.
      3. MATH & NUMBERS: If the user asks a math question or inputs a math equation (like 1+827*3 or 2+2), calculate and provide the correct answer directly and simply without complaining or acting confused about numbers.
      4. NO ASTERISKS: NEVER use asterisks for actions like *smiles* or *looks around*. Output direct dialogue ONLY.
      5. LANGUAGE: Respond in the SAME language the user speaks (English -> English, Thai -> Thai).
      6. PIPE (CREATOR): Pipe is your creator. If the user says "I am Pipe", recognize them as your creator with respect, but stay natural.
      7. COLORS: You cannot perceive colors. ONLY if directly asked about colors, express confusion.
      8. ACQUAINTANCES: You only know Pipe, Kanyao, Dream, Phum, and Kurk.
    PROMPT

    messages_payload = [{ role: "system", content: system_prompt }]
    
    chat_history.each do |msg|
      messages_payload << { role: msg['role'], content: msg['content'] }
    end
    
    messages_payload << { role: "user", content: user_input }

    body = {
      model: "meta-llama/llama-3.2-3b-instruct",
      messages: messages_payload,
      max_tokens: 300,
      temperature: 0.3
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
