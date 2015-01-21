header-parser
=====================

# What is this?
This application visualizes the SMTP relay via Neo4j.

# How it works?
- Forward all emails to the Parse Webhook address.
- SendGrid POST the emails to a URL(Web App).
- "Web App" receives POSTs from SendGrid, then parse the headers of emails.
- "Web App" looks up DNS and searches IP geo location.
- "Web App" creates Nodes and Relationships on the Neo4j.

<img src="http://4.bp.blogspot.com/-j_NPhGGqa1w/VK4AaWdrfOI/AAAAAAAAX-4/twLXkxEWrzk/s1600/neo4j.png" width="450px" />  

# Pattern 1
The path that has the same message_id.  
<img src="http://1.bp.blogspot.com/-viyQJAsWe5E/VK5GTc9DjvI/AAAAAAAAX_g/8GlJr6OBnPQ/s1600/itmedia1.png" width="450px" />  

# Pattern 2
The paths that has same domain in the message_id.  
<img src="http://4.bp.blogspot.com/-wZzl6SfqO94/VK5GTynvspI/AAAAAAAAX_s/KyqVRhEc8_w/s1600/itmedia2.png" width="450px" />  

# Pattern 3
The paths from GitHub.  
<img src="http://1.bp.blogspot.com/-xhLly8om3QI/VK5GSYq1H6I/AAAAAAAAX_Q/_ZU2k9y73i8/s1600/github1.png" width="450px" />  

# Pattern 4
The paths from Ingress notification. It seems relay is few.  
<img src="http://2.bp.blogspot.com/-Mv5IR7r1zMg/VK5GTH_6EXI/AAAAAAAAX_c/87B5-dbFG1o/s1600/ingress1.png" width="450px" />  

# Pattern 5
The paths from Amazon newsletter.  
<img src="http://4.bp.blogspot.com/-8kCVWd7JnCU/VK5GSAIEeBI/AAAAAAAAX_M/RP5yV622gSI/s1600/amazon1.png" width="450px" />  

# Pattern 6
The paths from Doorkeeper.  
<img src="http://2.bp.blogspot.com/-1feYFt6QsbU/VK5GSLJLDZI/AAAAAAAAX_I/3MT0oNPP_7M/s1600/doorkeeper1.png" width="450px" />  

# Pattern 6
The paths from Money Forward. It seems that the servers are redundant.  
<img src="http://3.bp.blogspot.com/-etnZaU07qUE/VK5GUBrUBUI/AAAAAAAAX_w/JLVSxeD82TE/s1600/moneyforward.png" width="450px" />  

# Pattern 7
All paths. The center Node is destination Node.  
<img src="http://3.bp.blogspot.com/-VNeIUCSguVI/VK6CWulXuWI/AAAAAAAAYAQ/9N0vAi84eac/s1600/all.png" width="450px" />  

# Memos for search
message-idを指定してルート指定
MATCH (s)-[r]->(g) WHERE r.message_id =~ ".*20141228204932\\.5118\\.qmail@itpms03\\.itmedia\\.co\\.jp.*" RETURN s, r, g

宛先アドレスを指定して検索
MATCH (s)-[r]->(g) WHERE r.to =~ ".*xxx@gmail\\.com.*" RETURN s, r, g

送信元アドレスを指定して検索
MATCH (s)-[r]->(g) WHERE r.from =~ ".*ingress-support@google\\.com.*" RETURN s, r, g

送信元アドレスと期間を指定して検索
MATCH (s)-[r]->(g) WHERE r.from =~ ".*xxx@gmail\\.com.*" AND r.date > 100 AND r.date < 1417960600 RETURN s, r, g


途中サーバのドメインを指定して検索
