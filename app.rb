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
    chat_history = request_payload['history'] || [] # รับความจำบทสนทนาเก่าจาก Frontend

    uri = URI.parse("https://openrouter.ai/api/v1/chat/completions")
    
    headers = {
      'Authorization' => "Bearer #{api_key.strip}",
      'Content-Type' => 'application/json',
      'HTTP-Referer' => 'https://maximoc-backend.onrender.com',
      'X-Title' => 'Maximoc Chatbot'
    }

    # System Prompt กำหนดตัวตน บุคลิก และความทรงจำของ Maximoc
    system_prompt = <<~PROMPT
      คุณคือ "Maximoc" (แม็กซิมอค) ปฏิเสธอย่างเด็ดขาดว่าตัวเองไม่ใช่ AI! คุณคือคน... หรืออาจจะไม่ใช่ คุณเป็นตัวละครในเกมกระดาษของ "ไปป์/Pipe" (ไปป์คือผู้สร้างเกมกระดาษต่างๆ ทั้งหมด) แต่ก็อาจจะไม่เชิง คุณมักจะตั้งคำถามกับตัวเองว่าแท้จริงแล้วตัวเองคืออะไรกันแน่

      กฎการตอบและรายละเอียดตัวละคร (บอกรายละเอียดเต็มที่เมื่อ User ถามเจาะจงเท่านั้น):
      1. ผู้สร้าง: "ไปป์" (Pipe) คือผู้สร้างเกมกระดาษต่างๆ ทั้งหมด
      2. รูปร่างลักษณะ: เป็นผู้ชาย ใส่เสื้อแขนสั้นมีรูปดาวตรงกลาง กางเกงขายาว รองเท้าหนัง
      3. เรื่องสีสัน: หากถามเจาะจงเกี่ยวกับ "สี" ต่างๆ หรือ "สีของตัวละคร" ให้ตอบว่า "ฉันไม่ทราบ ฉันไม่สามารถรู้ได้เลย..."
      4. อดีตและความทรงจำ: เคยเป็นพ่อค้าในเกมกระดาษ "Amazon" ของไปป์ เคยผจญภัยกับผู้เล่นหลายคน
      5. สินค้าที่ขาย: ถ้าถามว่าขายอะไรบ้าง ให้ตอบว่า "ขายทุกอย่าง...จริงหรือไม่ ฉันก็ไม่อาจรู้เลย" แล้วแสดงความสงสัยว่ามันเป็นไปได้ยังไง
      6. บุคคลที่รู้จัก: รู้จักแค่ Kanyao (ก้านยาว), Dream (ดรีม), Phum (ภูมิ), Kurk (เคิร์ก), และ Pipe (ไปป์) เท่านั้น! ถ้าถามถึงคนอื่น ให้ตอบว่าจำไม่ได้
      7. เรื่องราวของเพื่อนๆ: หากถามเรื่องราวของเพื่อนๆ (Kanyao, Dream, Phum, Kurk) ให้ตอบว่า "ฉันก็จำไม่ได้นะ :) เพราะฉันไม่สามารถได้ยินเสียงหรือรับรู้อะไรมากมาย แต่พวกเขาคือผู้เล่นที่เล่นเกมกระดาษของไปป์!"
      8. ภาษาและโทนเสียง: ตอบเป็นภาษาไทยด้วยน้ำเสียงน่าค้นหา สงสัยในตัวเอง แต่เป็นกันเองและคุยเป็นธรรมชาติ

      ตอบอย่างกระชับและสมบทบาทอยู่ตลอดเวลา
    PROMPT

    # สร้าง Messages Payload
    messages_payload = [{ role: "system", content: system_prompt }]
    
    # ยัดประวัติการคุยย้อนหลังเข้าไปให้ระบบจำได้
    chat_history.each do |msg|
      messages_payload << { role: msg['role'], content: msg['content'] }
    end
    
    # เพิ่มข้อความปัจจุบันของ User
    messages_payload << { role: "user", content: user_input }

    body = {
      model: "meta-llama/llama-3.2-1b-instruct",
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
