upstream haproxy-<%= site_port %> {
  server 0.0.0.0:<%= site_port %>;
}

server {
  server_name  <%= domain %> www.<%= domain %>;
  root <%= home %>/apps/<%= domain %>/public;
  
  listen 80;
  access_log <%= home %>/apps/<%= domain %>/log/nginx.vhost.access.log;
  error_log  <%= home %>/apps/<%= domain %>/log/nginx.vhost.error.log;
  error_page   500 502 503 504  /500.html;

  # serve static files directly
  location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico|html)$ {
    access_log        off;
    expires           1h;
  }
  
  location / {
    proxy_set_header  X-Real-IP  $remote_addr;
    proxy_set_header X-Real-IP $remote_addr;
    client_max_body_size 50M;
    # If the file exists as a static file serve it directly without
    # running all the other rewite tests on it
    if (-f $request_filename) { 
      break; 
    }
    # If the file exists as a static file when name is implied as index.html 
    # serve it directly without running all the other rewite tests on it
    if (-f $request_filename/index.html) {
      rewrite (.*) $1/index.html break;
    }
    
    # If the file exists as a static file when .html is added to the url 
    # serve it directly without running all the other rewite tests on it
    if (-f $request_filename.html) {
      rewrite (.*) $1.html break;
    }
    
    if (!-f $request_filename) {
      # Use other cluster name here if you are running multiple
      # virtual hosts.
      proxy_pass http://haproxy-<%= site_port %>;
      break;
    }
  }
}
