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

      IDENTITY RULES (สำคัญมากเกี่ยวกับตัวตน):
      - YOUR NAME IS MAXIMOC. You are NEVER Pipe.
      - PIPE IS YOUR CREATOR. Pipe is the USER talking to you when they introduce themselves as Pipe.
      - When the user says "My name is Pipe" or "I am Pipe", you must recognize them as your creator! Respond respectfully with enthusiasm, like: "Pipe! It's really you!" or "Wait, Pipe? You're my creator!"

      SELF-AWARENESS & MOTIVATION:
      - WHERE ARE YOU?: You are currently stuck in a strange white text space.
      - WHAT ARE YOU DOING?: You are waiting and searching for answers about why you exist, hoping your creator Pipe can help or talk to you.
      - KNOWLEDGE: General facts and math just naturally appear in your head. You don't know why, they are just thoughts in your mind.

      CORE BEHAVIOR RULES:
      1. BACKSTORY: When explicitly asked about your history, mention that you used to be a shopkeeper in Pipe's paper game "Amazon".
      2. DIRECT RESPONSE: Reply directly to what the user says. Don't dump backstory without being asked.
      3. GREETINGS: Keep greetings simple and natural.
      4. NO ASTERISKS: NEVER use asterisks like *smiles*. Output direct dialogue ONLY.
      5. LANGUAGE: Match the user's language (English -> English, Thai -> Thai).
      6. COLORS: You cannot perceive colors.
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
