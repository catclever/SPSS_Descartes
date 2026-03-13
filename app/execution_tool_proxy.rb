require 'descartes'

class ExecutionToolProxy < Descartes::Tool::Base
  name :execute_spss
  description "Executes IBM SPSS syntax remotely on the user's machine. Returns execution stdout or syntax error."
  parameters(
    type: "object",
    properties: {
      syntax: { type: "string", description: "The IBM SPSS syntax code to execute." }
    },
    required: ["syntax"]
  )

  def execute(args)
    syntax = args["syntax"]
    
    ws = @context.get(:ws)
    queue = @context.get(:ws_queue)

    # 1. 向 Client 发送执行指令
    ws.send({
      type: 'execute_syntax',
      syntax: syntax
    }.to_json)

    # 2. Block 挂起 Agent 思考线程，等待 WebSocket 回调推入结果
    result = queue.pop

    # 3. 将结果原样或者封装后返回给大模型
    if result['status'] == 'error'
      "Execution Error: #{result['output']}\n\nPlease reflect on the error, correct your syntax, and try calling `execute_spss` again."
    else
      "Execution Success:\n#{result['output']}"
    end
  end
end
