require 'sinatra'
require 'net/http'
require 'uri'
require 'json'
require 'resolv'

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
  
  token = ENV['HF_TOKEN']
  
  if token.nil? || token.strip.empty?
    return { status: 'error', message: 'ยังไม่ได้ตั้งค่า HF_TOKEN ใน Environment Variables บน Render' }.to_json
  end

  begin
    request_payload = JSON.parse(request.body.read)
    user_input = request_payload['message'] || ""

    model_id = "microsoft/Phi-3-mini-4k-instruct"
    
    # ใช้อารเรย์ของ Endpoint สำรองหาก DNS ตัวแรกมีปัญหา
    endpoints = [
      "https://router.huggingface.co/hf-inference/v1/chat/completions",
      "https://api-inference.huggingface.co/models/#{model_id}"
    ]

    response = nil
    last_error = nil

    endpoints.each do |ep|
      begin
        uri = URI.parse(ep)
        http = Net::HTTP.new(uri.hostname, uri.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 25

        headers = {
          'Authorization' => "Bearer #{token.strip}",
          'Content-Type' => 'application/json'
        }

        # กำหนดโครงสร้าง Body ให้รองรับตามประเภท Endpoint
        if ep.include?("v1/chat/completions")
          body = {
            model: model_id,
            messages: [
              { role: "system", content: "You are Maximoc, a clever AI assistant. Answer briefly." },
              { role: "user", content: user_input }
            ],
            max_tokens: 200,
            temperature: 0.7
          }.to_json
        else
          prompt = "<|user|>\nYou are Maximoc, a clever AI assistant. Answer this briefly: #{user_input}<|end|>\n<|assistant|>"
          body = {
            inputs: prompt,
            parameters: { max_new_tokens: 200, temperature: 0.7, return_full_text: false }
          }.to_json
        end

        req = Net::HTTP::Post.new(uri.request_uri, headers)
        req.body = body

        res = http.request(req)
        if res.code.to_i == 200
          response = res
          break
        end
      rescue => err
        last_error = err.message
      end
    end

    if response.nil?
      return { status: 'error', message: "เครือข่ายเชื่อมต่อไม่ได้: #{last_error}" }.to_json
    end

    data = JSON.parse(response.body)

    # ดึงผลลัพธ์จาก OpenAI-style response (ถ้าใช้ router.huggingface.co)
    if data['choices'] && data['choices'][0] && data['choices'][0]['message']
      reply_text = data['choices'][0]['message']['content'].strip
      { status: 'success', reply: reply_text }.to_json
    # ดึงผลลัพธ์จาก Legacy Inference API
    elsif data.is_a?(Array) && data[0] && data[0]['generated_text']
      reply_text = data[0]['generated_text'].strip
      { status: 'success', reply: reply_text }.to_json
    else
      { status: 'error', message: "รูปแบบข้อมูลตอบกลับไม่ถูกต้อง: #{response.body[0..100]}" }.to_json
    end

  rescue => e
    status 500
    { status: 'error', message: e.message }.to_json
  end
end
