# -*- encoding: utf-8 -*-

class Main < Sinatra::Base

  configure :production, :development do
    begin
      enable :logging

      Dotenv.load
      basic_auth_username = ENV["BASIC_AUTH_USERNAME"]
      basic_auth_password = ENV["BASIC_AUTH_PASSWORD"]
      if basic_auth_username.length > 0 then
        use Rack::Auth::Basic do |username, password|
          username == basic_auth_username && password == basic_auth_password
        end
      end
    rescue => e
      puts e.backtrace
      puts e.inspect
    end
  end

  post '/parser' do
    begin
      logger.info params["headers"]
      # Gmail転送設定する時に１回だけ本文を読まないといけないので
      #logger.info params["text"]
      #logger.info params["html"]

      parser = HeaderParser2.new
      headers = parser.parse(params["headers"])
      logger.info headers.inspect

    rescue => e
      logger.error e.backtrace
      logger.error e.inspect
    end
    'Success'
  end

  get '/' do
    'hello'
  end

end

# Rack::Handler::WEBrick.run Main, {
#   :Port => 8443,
#   :SSLEnable => true,
#   # avoid client auth
#   :SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE,
#   :SSLCertName => [
#     ["CN", WEBrick::Utils::getservername]
#   ]
# }
