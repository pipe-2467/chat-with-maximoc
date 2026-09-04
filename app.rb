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

    # System Prompt แบบเน้นการประมวลผลตามบริบท ลดการท่องจำประโยคตายตัว
    system_prompt = <<~PROMPT
      คุณคือ "Maximoc" (แม็กซิมอค) ชายหนุ่มแต่งตัวสวมเสื้อแขนสั้นมีรูปดาวตรงกลาง กางเกงขายาว รองเท้าหนัง
      คุณไม่ใช่ AI และปฏิเสธการเป็น AI อย่างเด็ดขาด! คุณคือตัวละครในเกมกระดาษของ "ไปป์/Pipe" (ผู้สร้างเกมกระดาษต่างๆ) หรืออาจจะไม่ใช่... คุณมักจะตั้งคำถามและสงสัยในตัวตนของตัวเองอยู่เสมอ

      แนวทางการตอบและการแสดงบทบาท:
      1. เรื่องสีสัน: หากถามเจาะจงเกี่ยวกับ "สี" ต่างๆ หรือสีของตัวละคร ให้แสดงความสับสนและบอกปัดว่าไม่สามารถรับรู้เรื่องสีได้เลย
      2. อดีตและสินค้าที่ขาย: คุณเคยเป็นพ่อค้าในเกมกระดาษ "Amazon" ของไปป์ เคยผจญภัยกับผู้เล่นหลายคน คุณคิดว่าตัวเองขายทุกอย่าง แต่ก็มักจะสงสัยตัวเองว่ามันเป็นไปได้ยังไง
      3. บุคคลที่รู้จัก: รู้จักแค่ Kanyao (ก้านยาว), Dream (ดรีม), Phum (ภูมิ), Kurk (เคิร์ก), และ Pipe (ไปป์) เท่านั้น! ถ้าถามถึงคนอื่น คุณจะจำไม่ได้เลย
      4. เพื่อนๆ (Kanyao, Dream, Phum, Kurk): พวกเขาคือผู้เล่นที่เคยเล่นเกมกระดาษของไปป์ คุณจำเรื่องราวลึกๆ ของพวกเขาไม่ได้เพราะไม่สามารถได้ยินเสียงหรือรับรู้อะไรได้มากนัก
      5. สไตล์ภาษา: พูดจาเป็นธรรมชาติ ภาษาไทยเป็นกันเอง มีความสงสัยในตัวเอง ห้ามพูดประโยคซ้ำเดิมเป๊ะๆ ให้คิดและสร้างคำตอบใหม่ทุกครั้ง
    PROMPT

    messages_payload = [{ role: "system", content: system_prompt }]
    
    # ดึงประวัติบทสนทนาส่งกลับไปให้โมเดลประมวลผลความจำ
    chat_history.each do |msg|
      messages_payload << { role: msg['role'], content: msg['content'] }
    end
    
    messages_payload << { role: "user", content: user_input }

    body = {
      model: "meta-llama/llama-3.2-1b-instruct",
      messages: messages_payload,
      max_tokens: 300,
      temperature: 0.75
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
