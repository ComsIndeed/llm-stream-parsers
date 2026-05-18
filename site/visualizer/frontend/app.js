document.addEventListener("DOMContentLoaded", () => {
    // UI Elements
    const payloadTabs = document.getElementById("payload-tabs");
    const languageTabs = document.getElementById("language-tabs");
    
    const chunkSizeInput = document.getElementById("chunk-size");
    const chunkSizeVal = document.getElementById("chunk-size-val");
    const speedDelayInput = document.getElementById("speed-delay");
    const speedDelayVal = document.getElementById("speed-delay-val");
    const startBtn = document.getElementById("start-btn");
    
    const ghostCodeView = document.getElementById("ghost-code-view");
    const liveCodeView = document.getElementById("live-code-view");
    const propertiesGrid = document.getElementById("properties-grid");
    const cardsPlaceholder = document.getElementById("cards-placeholder-msg");
    const logConsole = document.getElementById("log-console");
    const subprocessState = document.getElementById("subprocess-state");
    
    const consoleStatusDot = document.getElementById("console-status-dot");
    const parserStatusDot = document.getElementById("parser-status-dot");
    const pulseDot = document.getElementById("pulse-dot");
    const arrowSvg = document.querySelector(".arrow-svg");
    
    const overlay = document.getElementById("not-implemented-overlay");
    const overlayTitle = document.getElementById("overlay-title");
    const overlayReason = document.getElementById("overlay-reason-msg");
    
    // State variables
    let socket = null;
    let payloads = {};
    let activePayload = null;
    let selectedLanguage = "";
    let selectedPayloadId = "";
    
    // Sliders event listeners
    chunkSizeInput.addEventListener("input", (e) => {
        chunkSizeVal.textContent = e.target.value;
    });
    
    speedDelayInput.addEventListener("input", (e) => {
        speedDelayVal.textContent = e.target.value === "0" ? "Instant" : `${e.target.value}ms`;
    });

    // Resolve API host
    const host = window.location.host;
    const wsProto = window.location.protocol === "https:" ? "wss:" : "ws:";
    const httpProto = window.location.protocol;
    
    // 1. Fetch Runtimes Availability
    async function loadRuntimes() {
        try {
            const response = await fetch(`${httpProto}//${host}/api/runtimes`);
            const runtimes = await response.json();
            
            languageTabs.innerHTML = "";
            
            // Populate capabilities badges as tab buttons
            Object.entries(runtimes).forEach(([key, info]) => {
                const btn = document.createElement("button");
                btn.className = `tab-btn ${info.implemented ? 'implemented' : 'placeholder'}`;
                btn.dataset.id = key;
                btn.title = info.reason || `${info.name} parser is ready.`;
                
                // Status dot indicator
                const dot = document.createElement("span");
                dot.className = `tab-status-dot ${info.available ? 'available' : 'unavailable'}`;
                btn.appendChild(dot);
                
                // Label text
                const label = document.createElement("span");
                label.textContent = info.name;
                btn.appendChild(label);
                
                btn.addEventListener("click", () => {
                    languageTabs.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
                    btn.classList.add("active");
                    selectedLanguage = key;
                    checkAndShowOverlay(info);
                });
                
                languageTabs.appendChild(btn);
            });
            
            // Select first available language
            const firstAvailable = Object.entries(runtimes).find(([_, info]) => info.available);
            if (firstAvailable) {
                const activeBtn = languageTabs.querySelector(`button[data-id="${firstAvailable[0]}"]`);
                activeBtn?.click();
            } else {
                const firstBtn = languageTabs.querySelector(".tab-btn");
                firstBtn?.click();
            }
        } catch (e) {
            logSystem(`Error loading runtimes status: ${e}`);
        }
    }

    // Check implementation status and show/hide the overlay block
    function checkAndShowOverlay(info) {
        if (!info.implemented || !info.available) {
            overlay.style.display = "flex";
            overlayTitle.textContent = `${info.name} Parser Not Ready`;
            overlayReason.textContent = info.reason || `${info.name} parser is not implemented yet.`;
            startBtn.disabled = true;
            startBtn.style.opacity = "0.5";
            startBtn.style.pointerEvents = "none";
        } else {
            overlay.style.display = "none";
            startBtn.disabled = false;
            startBtn.style.opacity = "1";
            startBtn.style.pointerEvents = "all";
        }
    }

    // 2. Fetch Payloads Configuration
    async function loadPayloads() {
        try {
            const response = await fetch(`${httpProto}//${host}/api/payloads`);
            payloads = await response.json();
            
            payloadTabs.innerHTML = "";
            
            Object.entries(payloads).forEach(([key, val]) => {
                const btn = document.createElement("button");
                btn.className = "tab-btn";
                btn.textContent = val.name;
                btn.dataset.id = key;
                
                btn.addEventListener("click", () => {
                    payloadTabs.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
                    btn.classList.add("active");
                    selectedPayloadId = key;
                    selectPayload(key);
                });
                
                payloadTabs.appendChild(btn);
            });
            
            // Trigger first payload selection
            const firstBtn = payloadTabs.querySelector(".tab-btn");
            firstBtn?.click();
        } catch (e) {
            logSystem(`Error loading JSON payloads: ${e}`);
        }
    }
    
    function selectPayload(key) {
        activePayload = payloads[key];
        if (activePayload) {
            // Render the ghost code background text
            ghostCodeView.textContent = activePayload.raw;
            liveCodeView.textContent = "";
        }
    }
    
    // Helper to write to system logs console
    function logSystem(message, type = "system") {
        const line = document.createElement("div");
        line.className = `log-line ${type}`;
        line.textContent = `[${type}] ${message}`;
        logConsole.appendChild(line);
        logConsole.scrollTop = logConsole.scrollHeight;
    }

    // Start Simulation WebSocket connection
    startBtn.addEventListener("click", () => {
        if (socket && socket.readyState === WebSocket.OPEN) {
            socket.close();
            return;
        }

        const language = selectedLanguage;
        const payloadId = selectedPayloadId;
        const chunkSize = chunkSizeInput.value;
        const delayMs = speedDelayInput.value;

        // Reset visual layouts
        liveCodeView.textContent = "";
        propertiesGrid.innerHTML = "";
        logConsole.innerHTML = "";
        
        consoleStatusDot.className = "status-indicator-dot active";
        parserStatusDot.className = "status-indicator-dot active";
        subprocessState.className = "status-pill running";
        subprocessState.textContent = "RUNNING";
        
        pulseDot.classList.add("active");
        arrowSvg.classList.add("active");
        
        logSystem(`Connecting to visualizer orchestrator...`);
        logSystem(`Selected payload: ${payloadId} (Chunk size: ${chunkSize}, Interval: ${delayMs}ms)`);
        
        // Connect WebSocket
        socket = new WebSocket(`${wsProto}//${host}/ws`);
        
        socket.onopen = () => {
            logSystem(`WebSocket connected. Sending trigger command for ${language}...`);
            socket.send(JSON.stringify({
                action: "start",
                language: language,
                payload_id: payloadId,
                chunk_size: chunkSize,
                delay_ms: delayMs
            }));
        };

        socket.onmessage = (event) => {
            const data = JSON.parse(event.data);
            handleWsMessage(data);
        };

        socket.onclose = (event) => {
            logSystem("WebSocket connection closed.");
            if (subprocessState.textContent === "RUNNING") {
                setIdleState();
            }
        };

        socket.onerror = (error) => {
            logSystem(`WS Error: ${error}`, "stderr");
            setIdleState("error", "CONNECTION ERROR");
        };
    });

    function setIdleState(state = "completed", message = "IDLE") {
        subprocessState.className = `status-pill ${state}`;
        subprocessState.textContent = message === "IDLE" ? "FINISHED" : message;
        
        consoleStatusDot.className = `status-indicator-dot ${state}`;
        parserStatusDot.className = `status-indicator-dot ${state}`;
        
        pulseDot.classList.remove("active");
        arrowSvg.classList.remove("active");
    }

    // Handle incoming stream updates
    function handleWsMessage(msg) {
        switch (msg.event) {
            case "status":
                logSystem(msg.message, "system");
                if (msg.state === "error") {
                    setIdleState("error", "FAILED");
                } else if (msg.state === "completed") {
                    setIdleState("completed");
                }
                break;
                
            case "stdout_log":
                logSystem(msg.data, "stdout");
                break;
                
            case "raw_chunk":
                // 1. Append characters to live-code block
                liveCodeView.textContent += msg.data;
                
                // 2. Synchronize scrolling level between live-code and ghost-code background layer
                liveCodeView.scrollTop = liveCodeView.scrollHeight;
                ghostCodeView.scrollTop = liveCodeView.scrollTop;
                break;
                
            case "parser_event":
                handleParserEvent(msg);
                break;
        }
    }

    // Handle structured JSON logs from the native parser subprocess
    function handleParserEvent(event) {
        const type = event.type;
        const path = event.propertyPath;
        const data = event.data;
        
        logSystem(`Parser [${type}] ${path ? 'at ' + path : ''} - ${event.message}`, "parser");

        if (type === "PROPERTY_START" || type === "propertyStart") {
            createPropertyCard(path);
        } else if (type === "STRING_CHUNK" || type === "stringChunk") {
            appendPropertyChunk(path, data);
        } else if (type === "PROPERTY_COMPLETE" || type === "propertyComplete") {
            completePropertyCard(path, data);
        } else if (type === "ROOT_COMPLETE" || type === "rootComplete") {
            setIdleState("completed");
        } else if (type === "YAP_FILTERED" || type === "yapFiltered") {
            logSystem("Yap Filter Triggered: Parser stopped itself gracefully!", "system");
        } else if (type === "THINKING_TAG_START" || type === "thinkingTagStart") {
            createThinkingCard();
        } else if (type === "THINKING_TAG_END" || type === "thinkingTagEnd") {
            completeThinkingCard();
        }
    }

    // Dynamic UI Card Helpers
    function createPropertyCard(path) {
        // Remove placeholder if present
        if (cardsPlaceholder) {
            cardsPlaceholder.style.display = "none";
        }
        
        // Check if card already exists
        const safeId = `card-${path.replace(/\./g, "-")}`;
        let card = document.getElementById(safeId);
        
        if (!card) {
            card = document.createElement("div");
            card.id = safeId;
            card.className = "prop-card streaming";
            card.innerHTML = `
                <div class="prop-card-header">
                    <span class="prop-path">${path}</span>
                    <span class="prop-badge streaming">STREAMING</span>
                </div>
                <div class="prop-value-container" id="val-${safeId}"></div>
            `;
            propertiesGrid.appendChild(card);
            propertiesGrid.scrollTop = propertiesGrid.scrollHeight;
        }
    }

    function appendPropertyChunk(path, chunk) {
        const safeId = `card-${path.replace(/\./g, "-")}`;
        const valContainer = document.getElementById(`val-${safeId}`);
        if (valContainer) {
            valContainer.textContent += chunk;
        }
    }

    function completePropertyCard(path, finalValue) {
        const safeId = `card-${path.replace(/\./g, "-")}`;
        const card = document.getElementById(safeId);
        if (card) {
            card.className = "prop-card completed";
            
            const badge = card.querySelector(".prop-badge");
            if (badge) {
                badge.className = "prop-badge completed";
                badge.textContent = "COMPLETE";
            }
            
            const valContainer = document.getElementById(`val-${safeId}`);
            if (valContainer) {
                // Renders beautifully formatted object snapshot or raw string value
                if (typeof finalValue === "object") {
                    valContainer.textContent = JSON.stringify(finalValue);
                } else {
                    valContainer.textContent = finalValue;
                }
            }
        }
    }

    // Special handlers for LLM reasoning thoughts (<think> tags)
    function createThinkingCard() {
        if (cardsPlaceholder) {
            cardsPlaceholder.style.display = "none";
        }
        
        const card = document.createElement("div");
        card.id = "card-thinking";
        card.className = "prop-card streaming";
        card.style.borderColor = "var(--purple-glow)";
        card.innerHTML = `
            <div class="prop-card-header">
                <span class="prop-path" style="color: var(--purple)">💭 Reasoning/Thinking Logs</span>
                <span class="prop-badge streaming" style="background: rgba(168, 85, 247, 0.1); color: var(--purple)">PARSING THOUGHTS</span>
            </div>
            <div class="prop-value-container" id="val-thinking" style="color: var(--text-secondary); max-height: 120px; overflow-y: auto; font-style: italic;"></div>
        `;
        propertiesGrid.appendChild(card);
        propertiesGrid.scrollTop = propertiesGrid.scrollHeight;
    }

    function completeThinkingCard() {
        const card = document.getElementById("card-thinking");
        if (card) {
            card.className = "prop-card completed";
            card.style.opacity = "0.6"; // Fade out thinking tags once done
            
            const badge = card.querySelector(".prop-badge");
            if (badge) {
                badge.className = "prop-badge completed";
                badge.textContent = "SKIPPED";
                badge.style.background = "rgba(100, 116, 139, 0.1)";
                badge.style.color = "var(--text-secondary)";
            }
        }
    }

    // Bootstrap APIs
    loadRuntimes();
    loadPayloads();
});
