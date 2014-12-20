require 'sinatra'
require 'sinatra/base'
require 'json'
require 'dotenv'
require 'logger'
require 'resolv'
# for ssl
# require 'webrick/https'
# require 'openssl'

require File.join(File.dirname(__FILE__), 'src', 'main')
require File.join(File.dirname(__FILE__), 'src', 'ipinfodb')
require File.join(File.dirname(__FILE__), 'src', 'header_parser2')

use Rack::Reloader, 0
run Main
