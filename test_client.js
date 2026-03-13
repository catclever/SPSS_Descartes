const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:9292');

ws.on('open', function open() {
  console.log('Connected to server, sending init...');
  ws.send(JSON.stringify({
    type: "init",
    prompt: "我想要计算 gender 变量各个类别的数量以及所占百分比",
    schema: '{ "vars": ["gender", "age"] }'
  }));
});

ws.on('message', function incoming(data) {
  const msg = JSON.parse(data);
  console.log('Received Message from Server:', msg.type);
  console.dir(msg, { depth: null });

  if (msg.type === 'execute_syntax') {
    console.log(`\n--- Agent is trying to execute: ---\n${msg.syntax}\n----------------------------------`);
    
    // Simulate SPSS execution
    setTimeout(() => {
      if (msg.syntax.includes('gender')) {
        console.log('-> Sending SUCCESS...');
        ws.send(JSON.stringify({
          type: 'execution_result',
          status: 'success',
          output: 'FREQUENCIES /VARIABLES=gender\nValid N: 100\nMale: 40\nFemale: 60'
        }));
      } else {
        console.log('-> Sending ERROR...');
        ws.send(JSON.stringify({
          type: 'execution_result',
          status: 'error',
          output: 'Error: Variable not found in dictionary.'
        }));
      }
    }, 1500); // simulate 1.5s thinking time
  } else if (msg.type === 'finished') {
    console.log('Agent finished successfully!');
    ws.close();
  }
});

ws.on('close', () => {
  console.log('Disconnected from server');
});
