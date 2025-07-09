# WebSocket Testing Guide

This guide helps you verify that WebSocket upgrade handling over HTTPS is working properly.

## 1. Backend Server Verification

### Check if the server is running with HTTPS support:

```bash
# Test the health endpoint
curl -k https://api.aigear.tech/health

# Expected response:
# {"status": "healthy", "websocket_support": true}
```

### Check server logs for WebSocket connections:

When a client connects, you should see logs like:
```
WebSocket connection attempt from 192.168.1.100:12345
Headers: {'host': 'api.aigear.tech', 'upgrade': 'websocket', 'connection': 'upgrade', ...}
Query params: {}
WebSocket connected successfully. Total connections: 1
Connection URL: wss://api.aigear.tech/ws/chat
Connection scheme: wss
```

## 2. iOS App Testing

### Check Xcode Console for connection logs:

When the ChatbotView appears, you should see:
```
Connecting to WebSocket: wss://api.aigear.tech/ws/chat
Request headers: ["Authorization": "Bearer your-token-here"]
WebSocket connection established successfully
```

### Test connection status in the app:

1. Open the ChatbotView
2. Look for the connection status indicator (green dot = connected, red dot = disconnected)
3. Check the console for detailed logs

### Send a test message:

1. Type a message like "What gear should I bring?"
2. Check console for:
```
Sending WebSocket message: What gear should I bring?
WebSocket message sent successfully
Received WebSocket message: 🧢 Gear Suggestions:...
```

## 3. Manual WebSocket Testing

### Using wscat (WebSocket client):

```bash
# Install wscat
npm install -g wscat

# Connect to WebSocket (replace with your token)
wscat -c "wss://api.aigear.tech/ws/chat" \
  -H "Authorization: Bearer your-token-here"

# Send a test message
{"type": "chat", "message": "What gear should I bring?", "timestamp": 1234567890}
```

### Using browser developer tools:

```javascript
// Open browser console and run:
const ws = new WebSocket('wss://api.aigear.tech/ws/chat');

ws.onopen = function() {
    console.log('Connected to WebSocket');
    ws.send(JSON.stringify({
        type: 'chat',
        message: 'What gear should I bring?',
        timestamp: Date.now() / 1000
    }));
};

ws.onmessage = function(event) {
    console.log('Received:', JSON.parse(event.data));
};

ws.onerror = function(error) {
    console.error('WebSocket error:', error);
};
```

## 4. Common Issues and Solutions

### Issue: "Connection refused" or "Failed to establish WebSocket connection"

**Possible causes:**
- Server not running
- Wrong port (should be 443 for WSS)
- Firewall blocking connections
- SSL certificate issues

**Solutions:**
1. Check if server is running: `curl https://api.aigear.tech/health`
2. Verify SSL certificate: `openssl s_client -connect api.aigear.tech:443`
3. Check server logs for errors

### Issue: "Invalid WebSocket URL"

**Solution:**
- Verify the URL format: `wss://domain.com/ws/chat`
- Check for typos in the domain name

### Issue: "Authentication failed"

**Solution:**
- Verify the Bearer token is valid
- Check if the token is expired
- Ensure the Authorization header is properly formatted

### Issue: "WebSocket upgrade failed"

**Possible causes:**
- Server not configured for WebSocket upgrades
- Load balancer not forwarding WebSocket headers
- Missing upgrade headers

**Solutions:**
1. Check server configuration for WebSocket support
2. Verify load balancer settings
3. Check if the `/ws/chat` endpoint is properly configured

## 5. Network Debugging

### Check SSL/TLS connection:

```bash
# Test SSL handshake
openssl s_client -connect api.aigear.tech:443 -servername api.aigear.tech

# Check certificate
openssl x509 -in cert.pem -text -noout
```

### Check WebSocket upgrade headers:

```bash
# Use curl to test the upgrade request
curl -i -N -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
  https://api.aigear.tech/ws/chat
```

## 6. Performance Testing

### Test connection stability:

1. Send multiple messages rapidly
2. Test with poor network conditions
3. Verify reconnection behavior
4. Check memory usage

### Monitor server resources:

```bash
# Check active connections
netstat -an | grep :443 | grep ESTABLISHED | wc -l

# Monitor server logs
tail -f /var/log/your-app.log | grep WebSocket
```

## 7. Success Indicators

✅ **WebSocket is working correctly if you see:**

1. **Backend logs:**
   - "WebSocket connected successfully"
   - "Total connections: X"
   - Proper message processing logs

2. **iOS app:**
   - Green connection indicator
   - Successful message sending
   - Real-time responses
   - No connection errors in console

3. **Network:**
   - HTTPS handshake successful
   - WebSocket upgrade completed
   - Persistent connection maintained

4. **Functionality:**
   - Messages sent and received instantly
   - AI responses working
   - Connection remains stable
   - Proper error handling

## 8. Troubleshooting Checklist

- [ ] Server is running with HTTPS
- [ ] SSL certificates are valid
- [ ] WebSocket endpoint is configured
- [ ] CORS is properly set up
- [ ] Authentication is working
- [ ] Network allows WebSocket connections
- [ ] Load balancer supports WebSocket upgrades
- [ ] Client URL is correct (wss://)
- [ ] Authorization headers are included
- [ ] Server logs show successful connections 