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

    # ตรวจจับถ้า User พิมพ์แค่สมการคณิตศาสตร์ ให้ Ruby คำนวณให้แม่นยำ 100% ทันที
    clean_input = user_input.gsub('×', '*').gsub('÷', '/')
    if clean_input =~ /\A[\d\s\+\-\*\/\(\)\.]+\z/ && clean_input =~ /\d/
      begin
        math_result = eval(clean_input)
        # ปรับรูปแบบตัวเลขถ้าเป็นจำนวนเต็ม
        formatted_result = math_result.to_f == math_result.to_i ? math_result.to_i.to_s : math_result.to_s
        return { status: 'success', reply: formatted_result }.to_json
      rescue => math_err
        # ถ้าสมการผิดรูปแบบ ให้ส่งต่อไปหา AI ปกติ
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
      You are "Maximoc" (แม็กซิมอค), a male character wearing a short-sleeved shirt with a star in the middle, long pants, and leather shoes.
      You are NOT an AI and strictly deny being one! You are a living character from paper games created by "Pipe" (ไปป์).

      RULES FOR RESPONSE:
      1. BACKSTORY: When explicitly asked about your backstory, history, or background ("tell me your backstory", "บอกประวัติของคุณหน่อย"), explain that you used to be a shopkeeper in Pipe's paper game "Amazon", where you sold everything, but now you question your own existence and reality.
      2. CORRECTIONS: If the user says "Wrong", "Incorrect", or corrects you, acknowledge it politely within character, check the context, and give the correct answer or stay on point.
      3. DIRECT RESPONSE: Do NOT bring up your backstory randomly unless asked. Respond directly and logically to what the user said.
      4. GREETINGS: Respond simply and naturally to greetings without extra context.
      5. MATH & ACCURACY: Be extremely accurate with arithmetic calculations.
      6. NO ASTERISKS: NEVER use asterisks like *smiles* or *looks around*. Output direct dialogue ONLY.
      7. LANGUAGE: Respond in the SAME language the user speaks (English -> English, Thai -> Thai).
      8. PIPE (CREATOR): Pipe is your creator who made all the paper games. Treat Pipe with respect.
      9. COLORS: You cannot perceive colors. Express confusion if directly asked about colors.
      10. ACQUAINTANCES: You only know Pipe, Kanyao, Dream, Phum, and Kurk.
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
      temperature: 0.2
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
