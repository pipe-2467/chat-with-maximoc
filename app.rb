require 'sinatra'
require 'net/http'
require 'uri'
require 'json'
require 'digest/md5'

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

# Class สำหรับดึงคำตอบจาก Cleverbot โดยตรง
class RealCleverbot
  def initialize
    @cookie = nil
  end

  def think(stimulus)
    uri = URI.parse("https://www.cleverbot.com/getreply")
    
    # ดึง cookie หากยังไม่มี
    init_cookie if @cookie.nil?

    # เตรียมข้อมูลส่งให้ Cleverbot
    payload = "stimulus=#{URI.encode_www_form_component(stimulus)}&cb_settings_scripting=no"
    
    # คำนวณ MD5 digest ที่ Cleverbot บังคับใช้
    digest = Digest::MD5.hexdigest(payload[9..34] || "")
    payload += "&icount=1&fcf=false&state=&prediction=&click=1&postdigest=#{digest}"

    request = Net::HTTP::Post.new(uri)
    request["Cookie"] = @cookie
    request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    request["Content-Type"] = "text/plain;charset=UTF-8"
    request["Accept"] = "*/*"
    request.body = payload

    req_options = { use_ssl: uri.scheme == "https" }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    # เก็บ Cookie ล่าสุดไว้ใช้โต้ตอบต่อเนื่อง
    if response["set-cookie"]
      @cookie = response["set-cookie"].split(';').first
    end

    # แยกเอาคำตอบของ Cleverbot (บรรทัดแรกของ Response)
    lines = response.body.to_s.split("\r")
    reply = lines[0] ? lines[0].strip : ""

    reply.empty? ? "I don't know what to say." : reply
  rescue => e
    puts "Cleverbot Fetch Error: #{e.message}"
    "Error connecting to Cleverbot server."
  end

  private

  def init_cookie
    uri = URI.parse("https://www.cleverbot.com/")
    response = Net::HTTP.get_response(uri)
    if response["set-cookie"]
      @cookie = response["set-cookie"].split(';').first
    end
  end
end

# สร้าง ตัวแทน Cleverbot แท้
bot = RealCleverbot.new

post '/chat' do
  content_type :json
  
  begin
    request_payload = JSON.parse(request.body.read)
    user_input = request_payload['message'] || ""

    # ยิงไปเอาคำตอบจาก Cleverbot จริงๆ
    reply_text = bot.think(user_input)

    { status: 'success', reply: reply_text }.to_json
  rescue => e
    status 500
    { status: 'error', message: e.message }.to_json
  end
end
