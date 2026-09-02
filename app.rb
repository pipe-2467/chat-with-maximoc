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
  
  if token.nil? || token.strip.empty?
    return { status: 'error', message: 'ยังไม่ได้ตั้งค่า HF_TOKEN ใน Environment Variables บน Render' }.to_json
  end

  begin
    request_payload = JSON.parse(request.body.read)
    user_input = request_payload['message'] || ""

    model_id = "microsoft/Phi-3-mini-4k-instruct"
    uri = URI.parse("https://api-inference.huggingface.co/models/#{model_id}")
    
    prompt = "<|user|>\nYou are Maximoc, a clever AI assistant. Answer this briefly: #{user_input}<|end|>\n<|assistant|>"

    headers = {
      'Authorization' => "Bearer #{token.strip}",
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
    http.read_timeout = 25

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = body

    response = http.request(request)
    
    begin
      data = JSON.parse(response.body)
    rescue
      data = nil
    end

    if response.code.to_i == 200 && data.is_a?(Array) && data[0] && data[0]['generated_text']
      { status: 'success', reply: data[0]['generated_text'].strip }.to_json
    elsif data.is_a?(Hash) && data['error']
      { status: 'error', message: "HF API: #{data['error']}" }.to_json
    else
      { status: 'error', message: "HTTP #{response.code}: #{response.body[0..150]}" }.to_json
    end

  rescue => e
    status 500
    { status: 'error', message: e.message }.to_json
  end
end
