# -*- encoding: utf-8 -*-

require 'sendgrid_ruby'
require 'sendgrid_ruby/version'
require 'sendgrid_ruby/email'

class Mailer

  def initialize
    @logger = Logger.new(STDOUT)
    Dotenv.load
    @username = ENV["SENDGRID_USERNAME"]
    @password = ENV["SENDGRID_PASSWORD"]
  end

  def send(body)
    email = SendgridRuby::Email.new
    email.set_tos(ENV["TOS"].split(","))
    email.set_from("parser@parser.awwa500.bymail.in")
    email.set_subject("Parse Header Report")
    email.set_text(body)
    sendgrid = SendgridRuby::Sendgrid.new(@username, @password)
    sendgrid.send(email)
  end

end
