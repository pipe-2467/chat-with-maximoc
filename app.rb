require 'sinatra'
require 'net/http'
require 'uri'
require 'json'

set :bind, '0.0.0.0'
set :port, ENV['PORT'] || 4567

# ฟังก์ชันดึง Token จาก Environment Variable หรือดึงจาก Pastefy โดยอัตโนมัติ
def get_hf_token
  return ENV['HF_TOKEN'] if ENV['HF_TOKEN'] && !ENV['HF_TOKEN'].empty?

  begin
    uri = URI.parse("https://pastefy.app/5vQ4rv88/raw")
    response = Net::HTTP.get_response(uri)
    response.body.strip if response.is_a?(Net::HTTPSuccess)
  rescue => e
    puts "Error fetching token from Pastefy: #{e.message}"
    nil
  end
end

HF_TOKEN = get_hf_token

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
  
  begin
    request_payload = JSON.parse(request.body.read)
    user_input = request_payload['message'] || ""

    token = HF_TOKEN || get_hf_token

    if token.nil? || token.empty?
      return { status: 'error', message: 'Hugging Face Token is missing' }.to_json
    end

    # เรียกใช้โมเดล Microsoft Phi-3 Mini Instruct บน Hugging Face
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
        max_new_tokens: 250,
        temperature: 0.7,
        return_full_text: false
      }
    }.to_json

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.read_timeout = 25

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = body

    response = http.request(request)
    data = JSON.parse(response.body)

    if response.is_a?(Net::HTTPSuccess) && data.is_a?(Array) && data[0]['generated_text']
      reply_text = data[0]['generated_text'].strip
      { status: 'success', reply: reply_text }.to_json
    elsif data.is_a?(Hash) && data['error']
      # กรณีโมเดลกำลัง Cold Start บน Hugging Face Server
      { status: 'success', reply: "[Phi-3 กำลังโหลดเข้าความจำ เซิร์ฟเวอร์กำลังเริ่มทำงาน ลองส่งใหม่อีกครั้งใน 10-15 วินาที]" }.to_json
    else
      { status: 'error', message: 'Unable to get response from Phi-3' }.to_json
    end

  rescue => e
    status 500
    { status: 'error', message: e.message }.to_json
  end
end
