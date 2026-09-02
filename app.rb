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
  
  token = ENV['HF_TOKEN']
  
  if token.nil? || token.empty?
    return { status: 'error', reply: 'ยังไม่ได้ตั้งค่า HF_TOKEN ใน Environment Variable ของ Render' }.to_json
  end

  begin
    request_payload = JSON.parse(request.body.read)
    user_input = request_payload['message'] || ""

    # ใช้ Endpoint ของ Hugging Face Inference API
    model_id = "microsoft/Phi-3-mini-4k-instruct"
    uri = URI.parse("https://api-inference.huggingface.co/models/#{model_id}")
    
    prompt = "<|user|>\nYou are Maximoc, a clever AI assistant. Answer this briefly: #{user_input}<|end|>\n<|assistant|>"

    headers = {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
    
    body = {
      inputs: prompt,
      parameters: {
        max_new_tokens: 200,
        temperature: 0.7,
        return_full_text: false
      }
    }.to_json

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = body

    response = http.request(request)
    data = JSON.parse(response.body)

    if response.code.to_i == 200 && data.is_a?(Array) && data[0] && data[0]['generated_text']
      reply_text = data[0]['generated_text'].strip
      { status: 'success', reply: reply_text }.to_json
    elsif data.is_a?(Hash) && data['error']
      error_msg = data['error']
      if error_msg.include?("currently loading")
        { status: 'success', reply: "[Phi-3 กำลังเริ่มระบบ ลองส่งใหม่อีกครั้งใน 10-15 วินาที]" }.to_json
      else
        { status: 'success', reply: "[HF Error: #{error_msg}]" }.to_json
      end
    else
      { status: 'success', reply: "[Error response code: #{response.code}]" }.to_json
    end

  rescue => e
    status 500
    { status: 'error', message: e.message }.to_json
  end
end
