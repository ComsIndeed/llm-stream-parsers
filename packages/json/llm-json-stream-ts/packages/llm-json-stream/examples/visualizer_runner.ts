import readline from "readline";
import { JsonStreamParser } from "../src/index.js";

// Helper to read character-by-character from stdin
async function* getStdinCharStream(): AsyncGenerator<string, void, unknown> {
    // Set stdin to raw mode if possible or read buffer-by-buffer
    process.stdin.setEncoding("utf8");
    for await (const chunk of process.stdin) {
        for (const char of chunk) {
            yield char;
        }
    }
}

async function main() {
    // 1. Read first line of stdin (properties config JSON)
    const reader = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
        terminal: false
    });

    const configLine = await new Promise<string>((resolve) => {
        reader.once("line", (line) => {
            resolve(line);
        });
    });
    reader.close();

    let config: Record<string, string>;
    try {
        config = JSON.parse(configLine.trim());
    } catch (e) {
        console.log(JSON.stringify({ event: "status", state: "error", message: `Invalid config: ${e}` }));
        return;
    }

    // Initialize parser
    const parser = new JsonStreamParser(getStdinCharStream());

    // 2. Pre-register and listen to all properties based on config to log events
    // Since TS doesn't have an onLog callback, we dynamically subscribe to each property stream
    // and print events to stdout in real-time.
    for (const [path, type] of Object.entries(config)) {
        try {
            if (type === "string") {
                const stream = parser.getStringProperty(path);
                // Log start
                console.log(JSON.stringify({ event: "parser_event", type: "PROPERTY_START", propertyPath: path }));
                
                // Track chunks asynchronously
                (async () => {
                    for await (const chunk of stream) {
                        console.log(JSON.stringify({
                            event: "parser_event",
                            type: "STRING_CHUNK",
                            propertyPath: path,
                            data: chunk
                        }));
                    }
                    
                    // Log completion
                    const finalVal = await stream.promise;
                    console.log(JSON.stringify({
                        event: "parser_event",
                        type: "PROPERTY_COMPLETE",
                        propertyPath: path,
                        data: finalVal
                    }));
                })();
            } else if (type === "number") {
                const stream = parser.getNumberProperty(path);
                console.log(JSON.stringify({ event: "parser_event", type: "PROPERTY_START", propertyPath: path }));
                (async () => {
                    const finalVal = await stream.promise;
                    console.log(JSON.stringify({
                        event: "parser_event",
                        type: "PROPERTY_COMPLETE",
                        propertyPath: path,
                        data: finalVal
                    }));
                })();
            } else if (type === "boolean") {
                const stream = parser.getBooleanProperty(path);
                console.log(JSON.stringify({ event: "parser_event", type: "PROPERTY_START", propertyPath: path }));
                (async () => {
                    const finalVal = await stream.promise;
                    console.log(JSON.stringify({
                        event: "parser_event",
                        type: "PROPERTY_COMPLETE",
                        propertyPath: path,
                        data: finalVal
                    }));
                })();
            } else if (type === "null") {
                const stream = parser.getNullProperty(path);
                console.log(JSON.stringify({ event: "parser_event", type: "PROPERTY_START", propertyPath: path }));
                (async () => {
                    const finalVal = await stream.promise;
                    console.log(JSON.stringify({
                        event: "parser_event",
                        type: "PROPERTY_COMPLETE",
                        propertyPath: path,
                        data: finalVal
                    }));
                })();
            } else if (type === "object") {
                const stream = parser.getObjectProperty(path);
                console.log(JSON.stringify({ event: "parser_event", type: "PROPERTY_START", propertyPath: path }));
                (async () => {
                    const finalVal = await stream.promise;
                    console.log(JSON.stringify({
                        event: "parser_event",
                        type: "PROPERTY_COMPLETE",
                        propertyPath: path,
                        data: finalVal
                    }));
                })();
            } else if (type === "array") {
                const stream = parser.getArrayProperty(path);
                console.log(JSON.stringify({ event: "parser_event", type: "PROPERTY_START", propertyPath: path }));
                (async () => {
                    const finalVal = await stream.promise;
                    console.log(JSON.stringify({
                        event: "parser_event",
                        type: "PROPERTY_COMPLETE",
                        propertyPath: path,
                        data: finalVal
                    }));
                })();
            }
        } catch (e) {
            console.log(JSON.stringify({
                event: "status",
                state: "error",
                message: `Failed to register ${path}: ${e}`
            }));
        }
    }

    // Wait for the stream consumption to complete
    // In TS, this.consumeStreamPromise handles the consumption
    // Let's hook into parser's own lifecycle or wait for stdin to end
    await new Promise<void>((resolve) => {
        process.stdin.on("end", () => {
            resolve();
        });
    });

    await parser.dispose();
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
