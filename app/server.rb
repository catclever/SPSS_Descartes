require 'faye/websocket'

class Server
  KEEPALIVE_TIME = 15 # in seconds

  def call(env)
    if Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env, nil, {ping: KEEPALIVE_TIME})

      ws.on :open do |event|
        p [:open, ws.object_id]
        ws.send("Connected to Descartes SPSS Server")
      end

      ws.on :message do |event|
        p [:message, event.data]
        # Echo the message back to the client
        ws.send(event.data)
      end

      ws.on :close do |event|
        p [:close, ws.object_id, event.code, event.reason]
        ws = nil
      end

      # Return async Rack response
      ws.rack_response
    else
      # Normal HTTP request
      [200, {'Content-Type' => 'text/plain'}, ['Descartes SPSS Server is running. Please connect via WebSocket.']]
    end
  end
end
