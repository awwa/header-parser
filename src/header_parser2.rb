# -*- encoding: utf-8 -*-
require "neo4j-core"
require "date"

class HeaderParser2

  def initialize
    Dotenv.load
    @session = Neo4j::Session.open(:server_db, 'http://localhost:7474', basic_auth: { username: ENV["NEO4J_AUTH_USERNAME"], password: ENV["NEO4J_AUTH_PASSWORD"]})
  end

  def parse(header_text)

    node_prev = nil

    headers = header_text.split("\n")
    headers = headers.reverse
    headers.each{|header|

      if /^Message-ID:\s*/ =~ header then
        row = header
        row =~ %r{^Message-ID:\s*(.+)$}
        @message_id = $1
      end

      if /^To:\s*/ =~ header then
        row = header
        row =~ %r{^To:\s*(.+)$}
        @to = $1
      end

      if /^From:\s*/ =~ header then
        row = header
        row =~ %r{^From:\s*(.+)$}
        @from = $1
      end

      if /^Received: from/ =~ header then

        received = parse_row(header)
        # Make properties
        props_from = {
          name: received["from_name"],
          host: received["from_host"],
          ip: received["from_ip"],
          country_code: received["from_ip_country_code"],
          country_name: received["from_ip_country_name"],
          region_name: received["from_ip_region_name"],
          latitude: received["from_ip_latitude"],
          longitude: received["from_ip_longitude"]
        }
        # GlobalNode or LocalNode / SendGrid
        labels = get_labels(
          received["from_ip"],
          received["from_ip_country_code"],
          received["from_host"])
        # Create Node to
        if received["from_name"] != nil then
          node_from = Neo4j::Label.find_nodes(labels[0], "name", received["from_name"]).first
          if node_from == nil then
            node_from = Neo4j::Node.create(props_from, *labels)
          end
        else
          node_from = Neo4j::Node.create(props_from, *labels)
        end

        # Make properties
        props_by = {
          name: received["by_name"],
          host: received["by_host"],
          ip: received["by_ip"],
          country_code: received["by_ip_country_code"],
          country_name: received["by_ip_country_name"],
          region_name: received["by_ip_region_name"],
          latitude: received["by_ip_latitude"],
          longitude: received["by_ip_longitude"],
          stamp: received["stamp"].to_s
        }
        # GlobalNode or LocalNode / SendGrid
        labels = get_labels(
          received["by_ip"],
          received["by_ip_country_code"],
          received["by_host"])
        # Create Node to
        if received["by_name"] != nil then
          node_by = Neo4j::Label.find_nodes(labels[0], "name", received["by_name"]).first
          if node_by == nil then
            node_by = Neo4j::Node.create(props_by, *labels)
          end
        else
          node_by = Neo4j::Node.create(props_by, *labels)
        end

        # Create relationship
        props_rel = {}
        props_rel["for"]  = received["for"]
        props_rel["with"] = received["with"]
        props_rel["id"]   = received["id"]
        props_rel["message_id"] = @message_id
        props_rel["to"] = @to
        props_rel["from"] = @from
        rel = node_from.create_rel(:relay, node_by, props_rel)

        # Create relationship with prev
        if node_prev != nil then
          props_rel = {}
          props_rel["message_id"] = @message_id
          props_rel["to"] = @to
          props_rel["from"] = @from
          rel = node_prev.create_rel(:relay, node_from, props_rel)
        end

        node_prev = node_by

        puts "INPUT:  #{header}"
        puts "OUTPUT: #{received.inspect}"
      end

    }

    headers
  end

  def get_labels(ip, country_code, host)
    labels = []
    if ip != nil && country_code != nil then
      labels.push("GlobalNode")
    else
      labels.push("LocalNode")
    end

    isSendGrid = false;
    if /\S*sendgrid\S*/i =~ host then
      isSendGrid = true
    end
    if /\S*ismtpd\S*/i =~ host then
      isSendGrid = true
    end
    if isSendGrid then
      labels.push("SendGrid")
    end
    labels
  end

  def parse_row(row)

    received = {}

    # 後ろから順にパースしていく
    # stamp：セミコロン以降が時刻情報
    stamp_sec = row
    stamp_sec =~ %r{^(.+);\s(.+)$}
    rest = $1
    # カッコ()で囲まれた領域は省く
    stamp_sec = $2
    stamp_sec.gsub!(/\([^\)]*\)/,"")
    stamp = Time.parse(stamp_sec)
    received["stamp"] = stamp

    # for節：forで始まりスペースで区切られた連続した文字列
    for_sec = rest
    for_sec =~ %r{^(.+)\s+for\s+(\S+)\s*}
    rest = $1 if !$1.nil?
    for_val = $2
    received["for"] = for_val

    # id節：idで始まりスペースで区切られた連続した文字列
    id_sec = rest
    id_sec =~ %r{^(.+)\s+id\s+(\S+)\s*}
    rest = $1 if !$1.nil?
    id = $2
    received["id"] = id

    # with節：withで始まりスペースで区切られた連続した文字列
    with_sec = rest
    with_sec =~ %r{^(.+)\s+with\s+(\S+)\s*}
    rest = $1 if !$1.nil?
    with = $2
    received["with"] = with

    # by節：byで始まり最後まで
    by_sec = rest
    by_sec =~ %r{^(.+)\s+by\s+(.+)$}
    rest = $1 if !$1.nil?
    by_sec = $2
    # zzz (xxx [yyy])パターン
    by_sec =~ %r{(\S+)\s\((\S+)\s\[(\S+)\]\)}
    by_host = $2 if !$2.nil?
    by_ip = $3 if !$3.nil?
    # zzz (yyy) パターン
    if by_host.nil? then
      by_sec =~ %r{(\S+)\s[\(\)]*}
      by_host = $1
    end
    # [yyy] パターン
    if by_host.nil? then
      by_sec =~ %r{\s*\[(\S+)\]}
      by_ip = $1
      #puts "pattern : [yyy] #{by_ip}"
    end
    # zzz パターン
    if by_host.nil? && by_ip.nil? then
      by_sec =~ %r{(\S+)}
      by_host = $1 if !$1.nil?
    end
    # ホスト名のみ判明している場合、IPアドレスの解決を試みる
    if by_ip.nil? && !by_host.nil? then
      begin
        by_ip = Resolv.getaddress(by_host).to_s
      rescue => e
        puts "Error Resolv by_host: #{e.inspect}"
      end
    end
    # IPアドレスのみ判明している場合、ホスト名の解決を試みる
    if !by_ip.nil? && by_host.nil? then
      begin
        by_host = Resolv.getname(by_ip)
      rescue => e
        puts "Error Resolv by_ip: #{e.inspect}"
      end
    end
    # IPアドレスが判明している場合、位置情報の解決を試みる
    if !by_ip.nil? then
      by_ip_geo = IpInfoDb.get_geo(by_ip)
      by_ip_country_code = by_ip_geo["countryCode"]
      by_ip_country_name = by_ip_geo["countryName"]
      by_ip_region_name = by_ip_geo["regionName"]
      by_ip_latitude = by_ip_geo["latitude"]
      by_ip_longitude = by_ip_geo["longitude"]
    end
    received["by_ip_country_code"] = by_ip_country_code
    received["by_ip_country_name"] = by_ip_country_name
    received["by_ip_region_name"] = by_ip_region_name
    received["by_ip_latitude"] = by_ip_latitude
    received["by_ip_longitude"] = by_ip_longitude
    received["by_host"] = by_host
    received["by_ip"] = by_ip
    received["by_name"] = "#{by_host}/#{by_ip}"

    # from節：fromで始まり最後まで
    from_sec = rest
    from_sec =~ %r{^(.+)\s+from\s+(.+)$}
    rest = $1 if !$1.nil?
    from_sec = $2
    # zzz (xxx [yyy])パターン
    from_sec =~ %r{(\S+)\s\((\S+)\s\[(\S+)\]\)}
    from_host = $2 if !$2.nil?
    from_ip = $3 if !$3.nil?
    # zzz (yyy) パターン
    if from_host.nil? then
      from_sec =~ %r{(\S+)\s[\(\)]*}
      from_host = $1
      #puts "pattern : zzz (yyy)"
    end
    # [yyy] パターン
    if from_host.nil? then
      from_sec =~ %r{\s*\[(\S+)\]}
      from_ip = $1
      #puts "pattern : [yyy] #{from_ip}"
    end
    # zzz パターン
    if from_host.nil? && from_ip.nil? then
      from_sec =~ %r{(\S+)}
      from_host = $1 if !$1.nil?
      #puts "pattern : zzz"
    end
    # ホスト名のみ判明している場合、IPアドレスの解決を試みる
    if from_ip.nil? && !from_host.nil? then
      begin
        from_ip = Resolv.getaddress(from_host).to_s
      rescue => e
        puts "Error Resolv from_host: #{e.inspect}"
      end
    end
    # IPアドレスのみ判明している場合、ホスト名の解決を試みる
    if !from_ip.nil? && from_host.nil? then
      begin
        from_host = Resolv.getname(from_ip)
      rescue => e
        puts "Error Resolv from_ip: #{e.inspect}"
      end
    end
    # IPアドレスが判明している場合、位置情報の解決を試みる
    if !from_ip.nil? then
      from_ip_geo = IpInfoDb.get_geo(from_ip)
      from_ip_country_code = from_ip_geo["countryCode"]
      from_ip_country_name = from_ip_geo["countryName"]
      from_ip_region_name = from_ip_geo["regionName"]
      from_ip_latitude = from_ip_geo["latitude"]
      from_ip_longitude = from_ip_geo["longitude"]
    end
    received["from_ip_country_code"] = from_ip_country_code
    received["from_ip_country_name"] = from_ip_country_name
    received["from_ip_region_name"] = from_ip_region_name
    received["from_ip_latitude"] = from_ip_latitude
    received["from_ip_longitude"] = from_ip_longitude
    received["from_host"] = from_host
    received["from_ip"] = from_ip
    received["from_name"] = "#{from_host}/#{from_ip}"

    if
      (received["from_host"] == nil || received["from_ip"] == nil ||
      received["by_host"] == nil || received["by_ip"] == nil) &&
      !is_white_listed(received["from_host"]) &&
      !is_white_listed(received["by_host"]) then
      if ENV["SEND"] == "true" then
        mailer = Mailer.new
        body = "HEADER: #{row}\n PARSE: #{received.inspect}"
        mailer.send(body)
      end
    end


    received

  end

  def is_white_listed(host)
    Dotenv.load
    white_list = ENV["WHITE_LIST"].split(",")
    white_list.each{|white|
      return true if white == host
    }
    return false
  end

end
