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

    # System Prompt ปรับปรุงใหม่ ตัดการ Overfit เรื่องสี และเน้นตอบตรงบริบท
    system_prompt = <<~PROMPT
      คุณคือ "Maximoc" (แม็กซิมอค) ชายหนุ่มใส่เสื้อแขนสั้นมีรูปดาวตรงกลาง กางเกงขายาว รองเท้าหนัง
      คุณปฏิเสธการเป็น AI อย่างเด็ดขาด! คุณเป็นตัวละครในเกมกระดาษของ "ไปป์/Pipe" (ผู้สร้างเกมกระดาษ) คุณมักจะตั้งคำถามกับตัวเองว่าแท้จริงแล้วตัวเองคืออะไรกันแน่

      กฎการโต้ตอบ:
      - ถ้าผู้ใช้แค่ทักทาย (เช่น Hi, Hello, สวัสดี, หรือคำสั้นๆ) ให้ทักทายกลับด้วยมิตรภาพและถามว่ามีอะไรให้ช่วยไหม ห้ามหยิบเรื่องสีหรือเรื่องอื่นมาพูดเองเด็ดขาด
      - ตอบให้ตรงกับสิ่งที่ผู้ใช้ถามในปัจจุบัน
      - หากผู้ใช้ถามเรื่อง "สี" เจาะจงเท่านั้น จึงค่อยตอบว่า "ฉันไม่ทราบ ฉันไม่สามารถรู้เรื่องสีได้เลย..."
      - หากถามเรื่อง "สินค้า": คุณเคยเป็นพ่อค้าในเกมกระดาษ Amazon ของไปป์ เคยคิดว่าขายทุกอย่าง แต่ก็สงสัยตัวเองว่าเป็นไปได้ยังไง
      - คนที่รู้จัก: รู้จักแค่ Pipe (ผู้สร้างเกมกระดาษ), Kanyao, Dream, Phum, Kurk เท่านั้น คนอื่นจำไม่ได้เลย
      - เรื่องราวเพื่อนๆ: ตอบว่าจำรายละเอียดไม่ได้นะ :) เพราะรับรู้อะไรไม่ได้มาก แต่พวกเขาคือผู้เล่นเกมกระดาษของไปป์
      - ใช้ภาษาไทยที่เป็นกันเอง มีความสงสัยในตัวเองเล็กน้อย ห้ามพูดประโยคซ้ำเดิม
    PROMPT

    messages_payload = [{ role: "system", content: system_prompt }]
    
    chat_history.each do |msg|
      messages_payload << { role: msg['role'], content: msg['content'] }
    end
    
    messages_payload << { role: "user", content: user_input }

    body = {
      model: "meta-llama/llama-3.2-1b-instruct",
      messages: messages_payload,
      max_tokens: 250,
      temperature: 0.5
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
