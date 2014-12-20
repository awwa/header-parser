# -*- encoding: utf-8 -*-
require "neo4j-core"
require "date"

class HeaderParser2

  def initialize
    @session = Neo4j::Session.open(:server_db)
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
        props_from = {name: received["from_name"],
          ip: received["from_ip"],
          country_code: received["from_ip_country_code"],
          country_name: received["from_ip_country_name"],
          region_name: received["from_ip_region_name"],
          latitude: received["from_ip_latitude"],
          longitude: received["from_ip_longitude"]
        }
        # GlobalNode or LocalNode
        label_from = get_label(received["from_ip"], received["from_ip_country_code"])
        # Create Node to
        if label_from == "GlobalNode" && received["from_ip"] != nil then
          node_from = Neo4j::Label.find_nodes(label_from, "ip", received["from_ip"]).first
          if node_from == nil then
            # TODO SendGrid関連サーバの場合、sendgridラベルを追加してもいいかも
            node_from = Neo4j::Node.create(props_from, label_from, "from")
          end
        else
          node_from = Neo4j::Node.create(props_from, label_from, "from")
        end

        # Make properties
        props_by = { name: received["by_name"],
          ip: received["by_ip"],
          country_code: received["by_ip_country_code"],
          country_name: received["by_ip_country_name"],
          region_name: received["by_ip_region_name"],
          latitude: received["by_ip_latitude"],
          longitude: received["by_ip_longitude"],
          stamp: received["stamp"].to_s
        }
        # GlobalNode or LocalNode
        label_by = get_label(received["by_ip"], received["by_ip_country_code"])
        # Create Node to
        if label_by == "GlobalNode" && received["by_ip"] != nil then
          node_by = Neo4j::Label.find_nodes(label_by, "ip", received["by_ip"]).first
          if node_by == nil then
            node_by = Neo4j::Node.create(props_by, label_by, "by")
          end
        else
          node_by = Neo4j::Node.create(props_by, label_by, "by")
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

  def get_label(ip, country_code)
    if ip != nil && country_code != nil then
      label = "GlobalNode"
    else
      label = "LocalNode"
    end
    label
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
    by_name = $2 if !$2.nil?
    by_ip = $3 if !$3.nil?
    # zzz (yyy) パターン
    if by_name.nil? then
      by_sec =~ %r{(\S+)\s[\(\)]*}
      by_name = $1
    end
    # zzz パターン
    if by_name.nil? then
      by_sec =~ %r{(\S+)}
      by_name = $1 if !$1.nil?
    end
    # ホスト名のみ判明している場合、IPアドレスの解決を試みる
    if by_ip.nil? && !by_name.nil? then
      begin
        by_ip = Resolv.getaddress(by_name).to_s
      rescue => e
        puts "Error Resolv by_name: #{e.inspect}"
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
    received["by_name"] = by_name
    received["by_ip"] = by_ip


    # from節：fromで始まり最後まで
    from_sec = rest
    from_sec =~ %r{^(.+)\s+from\s+(.+)$}
    rest = $1 if !$1.nil?
    from_sec = $2
    # zzz (xxx [yyy])パターン
    from_sec =~ %r{(\S+)\s\((\S+)\s\[(\S+)\]\)}
    from_name = $2 if !$2.nil?
    from_ip = $3 if !$3.nil?
    # zzz (yyy) パターン
    if from_name.nil? then
      from_sec =~ %r{(\S+)\s[\(\)]*}
      from_name = $1
    end
    # zzz パターン
    if from_name.nil? then
      from_sec =~ %r{(\S+)}
      from_name = $1 if !$1.nil?
    end
    # ホスト名のみ判明している場合、IPアドレスの解決を試みる
    if from_ip.nil? && !from_name.nil? then
      begin
        from_ip = Resolv.getaddress(from_name).to_s
      rescue => e
        puts "Error Resolv from_name: #{e.inspect}"
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
    received["from_name"] = from_name
    received["from_ip"] = from_ip

    received

  end

end
