message-idを指定してルート指定
MATCH (s)-[r]->(g) WHERE r.message_id =~ ".*20141228204932\\.5118\\.qmail@itpms03\\.itmedia\\.co\\.jp.*" RETURN s, r, g

宛先アドレスを指定して検索
MATCH (s)-[r]->(g) WHERE r.to =~ ".*xxx@gmail\\.com.*" RETURN s, r, g

送信元アドレスを指定して検索
MATCH (s)-[r]->(g) WHERE r.from =~ ".*ingress-support@google\\.com.*" RETURN s, r, g

送信元アドレスと期間を指定して検索
MATCH (s)-[r]->(g) WHERE r.from =~ ".*xxx@gmail\\.com.*" AND r.date > 100 AND r.date < 1417960600 RETURN s, r, g


途中サーバのドメインを指定して検索
