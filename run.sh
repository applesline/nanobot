#!/bin/bash

set -e

mkdir -p ./config ./workspace

chown -R 1000:1000 ./config ./workspace
chmod 750 ./config ./workspace

if [ ! -f ./config/config.json ]; then
    cat > ./config/config.json << EOF
{
  "providers": {
    "openrouter": {
      "apiKey": "YOUR_API_KEY_HERE"
    }
  },
  "agents": {
    "defaults": {
      "model": "anthropic/claude-3.5-sonnet"
    }
  },
  "tools": {
    "restrictToWorkspace": true
  }
}
EOF
    echo "Add your API key in ./config/config.json"
fi

docker build -t nanobot:secured .

echo "Start Nanobot container..."

docker run -d \
  --name nanobot \
  --user 1000:1000 \                    
  --read-only \                           
  --tmpfs /tmp \                           
  --tmpfs /home/nanobot/.nanobot/tmp \     
  --cap-drop ALL \                         
  --security-opt no-new-privileges:true \  
  -p 127.0.0.1:18790:18790 \               
  -v $(pwd)/config:/home/nanobot/.nanobot:ro \  
  -v $(pwd)/workspace:/app/workspace:rw \        
  nanobot:secured \
  gateway
