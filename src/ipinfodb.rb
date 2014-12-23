# -*- encoding: utf-8 -*-

$:.unshift File.dirname(__FILE__)
require "net/https"
require "rest-client"

module IpInfoDb

  def self.get_geo(ip_address)
    Dotenv.load
    api_key = ENV["IPINFODB_APIKEY"]
    url = "http://api.ipinfodb.com/v3/ip-city/?format=json&key=#{api_key}&ip=#{ip_address}"
    response = RestClient.get(url)
    geo = JSON.parse(response)
    if geo["statusCode"] == "OK" then
      ret = {}
      geo.each{|key, value|
        if value == "-" || value == "0" then
          ret[key] = nil
        else
          ret[key] = value
        end
      }
      ret
    else
      raise "Fail"
    end
  end

end
