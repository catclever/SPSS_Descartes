require 'faye/websocket'
require 'json'
require_relative 'agent_session'

class Server
  KEEPALIVE_TIME = 15

  def initialize
    @sessions = {}
  end

  def call(env)
    if Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env, nil, {ping: KEEPALIVE_TIME})

      ws.on :open do |event|
        p [:open, ws.object_id]
      end

      ws.on :message do |event|
        handle_message(ws, event.data)
      end

      ws.on :close do |event|
        p [:close, ws.object_id, event.code, event.reason]
        @sessions.delete(ws.object_id)
        ws = nil
      end

      ws.rack_response
    else
      [200, {'Content-Type' => 'text/plain'}, ['Descartes SPSS Server is running. Please connect via WebSocket.']]
    end
  end

  private

  def handle_message(ws, raw_data)
    data = JSON.parse(raw_data)
    session = @sessions[ws.object_id]

    case data['type']
    when 'init'
      ws.send({ type: 'status', message: 'Agent 初始环境完毕，正在构建并验证语法...' }.to_json)
      session = AgentSession.new(ws, data)
      @sessions[ws.object_id] = session
      session.start

    when 'execution_result'
      if session
        session.handle_execution_result(data)
      else
        p [:error, "Received execution_result for untracked session #{ws.object_id}"]
      end
    else
      p [:unknown_message_type, data['type']]
    end
  rescue JSON::ParserError
    ws.send({ type: 'error', message: 'Invalid JSON format' }.to_json)
  rescue StandardError => e
    p [:server_error, e.message]
    p e.backtrace
    ws.send({ type: 'error', message: 'Internal Server Error' }.to_json)
  end
end
