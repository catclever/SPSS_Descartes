# Descartes SPSS Server

The **Descartes SPSS Server** is a lightweight, strictly stateless Ruby WebSocket backend designed specifically for orchestrating the AI capabilities of the [SPSS Agent Desktop Client](https://github.com/catclever/spss-executor-go). 

It acts as an execution proxy. Because this server dynamically constructs Language Model (LLM) configuration profiles natively from the WebSocket JSON payloads injected by the desktop Electron/Wails client at runtime, it does **not** store any API keys hardcoded in the server environment. This guarantees strict security when deployed to cloud environments.

It bridges the intelligence of the [descartes](https://github.com/catclever/descartes) multi-agent framework directly to your local IBM SPSS execution engine through the encrypted WebSocket transport layer.

## Project Requirements

- **Ruby:** `~> 3.3.0`
- **Bundler:** For managing Gem dependencies.
- **Client App:** The frontend `spss-executor-go` Wails desktop app.

---

## 💻 Local Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/descartes-spss-server.git
   cd descartes-spss-server
   ```

2. **Install Ruby Dependencies:**
   ```bash
   bundle install
   ```

3. **Start the Puma Server locally:**
   ```bash
   bundle exec puma -t 5:5 -p 9292
   ```

4. **Connect the App:**
   Open the settings in your SPSS Agent Desktop App and set the **Ruby Server URL** to `ws://localhost:9292`.

---

## ☁️ Railway Cloud Deployment

This project natively supports one-click deployment to **[Railway.app](https://railway.app/)** with zero explicit hardware configurations required. WebSockets (`wss://`) routing is handled seamlessly by the Railway proxy ingress mapping.

1. **Push to GitHub**
   Ensure your local project is fully pushed to your remote GitHub repository (`master` or `main`).

2. **Deploy on Railway**
   - In your Railway dashboard, click **"New Project"** -> **"Deploy from GitHub repo"**.
   - Select your `descartes-spss-server` repository.
   
3. **Automatic Build & Binding**
   - The bundled `Dockerfile` and `railway.json` will automatically construct the container environment. 
   - Puma will dynamically bind to `0.0.0.0:$PORT` via `config/puma.rb` to securely listen to Railway's proxy traffic.
   - You **do not** need to configure any custom environment variables (No `API_KEY`s required!).

4. **Connect the App:**
   Once Railway completes the build, it will assign you a public domain (e.g., `spss-backend-xxxx.up.railway.app`). 
   Open the settings in your SPSS Agent Desktop App and set the **Ruby Server URL** to the encrypted WebSocket route using `wss://`:
   `wss://spss-backend-xxxx.up.railway.app`
