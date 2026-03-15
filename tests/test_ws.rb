require 'faye/websocket'
require 'eventmachine'
require 'json'

EM.run {
  ws = Faye::WebSocket::Client.new('ws://localhost:9292')

  ws.on :open do |event|
    p [:open]
    
    # 阶段 1: 挂载初始化
    init_msg = {
      type: 'init',
      prompt: '我要做方差分析',
      schema: '{ "vars": ["gender", "age"] }'
    }
    ws.send(init_msg.to_json)
  end

  ws.on :message do |event|
    data = JSON.parse(event.data)
    p [:server_says, data['type'], data]

    case data['type']
    when 'status'
      # Just log it
      puts "Status updated: #{data['message']}"
    when 'execute_syntax'
      # 阶段 2/3: 收到执行命令，模拟本地报错或成功
      syntax = data['syntax']
      puts "Executing syntax: #{syntax}"

      if syntax.include?('gendr')
        # 故意报错
        error_msg = {
          type: 'execution_result',
          status: 'error',
          output: 'Error: Variable gendr does not exist in dataset.'
        }
        puts "-> Sending simulated ERROR..."
        ws.send(error_msg.to_json)
      else
        # 成功
        success_msg = {
          type: 'execution_result',
          status: 'success',
          output: 'FREQUENCIES /VARIABLES=gender\n\nStatistics...\nValid N: 100'
        }
        puts "-> Sending simulated SUCCESS..."
        ws.send(success_msg.to_json)
      end
    when 'finished'
      puts "Agent Task Finished: #{data['final_syntax']}"
      ws.close
    end
  end

  ws.on :close do |event|
    p [:close, event.code, event.reason]
    EM.stop
  end
}
