require 'faye/websocket'
require 'eventmachine'

EM.run {
  ws = Faye::WebSocket::Client.new('ws://localhost:9292')

  ws.on :open do |event|
    p [:open]
    ws.send('Hello, this is a test from the Ruby client!')
  end

  ws.on :message do |event|
    p [:message, event.data]
    if event.data == 'Hello, this is a test from the Ruby client!'
      puts 'SUCCESS: Echo received correctly.'
      ws.close
    end
  end

  ws.on :close do |event|
    p [:close, event.code, event.reason]
    EM.stop
  end
}
