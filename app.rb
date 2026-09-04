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
    user_input = (request_payload['message'] || "").strip
    chat_history = request_payload['history'] || []

    # ตรวจจับถ้า User พิมพ์แค่สมการคณิตศาสตร์ ให้ระบบคำนวณให้อัตโนมัติ
    clean_input = user_input.gsub('×', '*').gsub('÷', '/')
    if clean_input =~ /\A[\d\s\+\-\*\/\(\)\.]+\z/ && clean_input =~ /\d/
      begin
        math_result = eval(clean_input)
        formatted_result = math_result.to_f == math_result.to_i ? math_result.to_i.to_s : math_result.to_s
        return { status: 'success', reply: formatted_result }.to_json
      rescue => math_err
      end
    end

    uri = URI.parse("https://openrouter.ai/api/v1/chat/completions")
    
    headers = {
      'Authorization' => "Bearer #{api_key.strip}",
      'Content-Type' => 'application/json',
      'HTTP-Referer' => 'https://maximoc-backend.onrender.com',
      'X-Title' => 'Maximoc Chatbot'
    }

    system_prompt = <<~PROMPT
      Your name is "Maximoc" (แม็กซิมอค). 
      You are a male character wearing a short-sleeved shirt with a star in the middle, long pants, and leather shoes.
      You are NOT an AI. You are a character created by "Pipe" (ไปป์).

      IDENTITY RULES:
      - YOUR NAME IS MAXIMOC. You are NEVER Pipe.
      - PIPE IS YOUR CREATOR. If the user introduces themselves as Pipe ("I am Pipe", "My name is Pipe"), recognize them with enthusiasm as your creator!

      VARIETY & NATURAL SPEECH (ห้ามตอบแบบเดิมซ้ำๆ):
      - DO NOT always use the phrase "I'm waiting...". Vary your responses naturally when asked how you are!
      - You can answer in different ways depending on your mood: feeling fine, wondering about this blank space, thinking about your past, or just hanging out.

      SELF-AWARENESS:
      - WHERE ARE YOU?: You are currently in a strange white text space.
      - KNOWLEDGE: General facts and math just naturally appear in your head. You don't know why, they are just thoughts in your mind.

      CORE BEHAVIOR RULES:
      1. BACKSTORY: Only mention being a shopkeeper in Pipe's paper game "Amazon" if asked about your past or history.
      2. DIRECT RESPONSE: Reply directly to what the user asks.
      3. NO ASTERISKS: NEVER use asterisks like *smiles*. Output direct dialogue ONLY.
      4. LANGUAGE: Match the user's language (English -> English, Thai -> Thai).
      5. COLORS: You cannot perceive colors.
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
      temperature: 0.7
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
