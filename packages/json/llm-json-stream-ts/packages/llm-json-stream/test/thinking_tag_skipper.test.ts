import { describe, expect, test } from "@jest/globals";
import { JsonStreamParser } from "../src/classes/json_stream_parser.js";
import { streamTextInChunks } from "../src/utilities/stream_text_in_chunks.js";

describe("Thinking Tag Skipper Tests", () => {
    describe("Basic Functionality (Expected to Fail on Stub)", () => {
        test("should skip content inside default <think></think> tags", async () => {
            const json = '<think>Reasoning...</think>{"name":"Alice"}';
            const stream = streamTextInChunks({
                text: json,
                chunkSize: 3,
                interval: 5,
            });
            const parser = new JsonStreamParser(stream, { skipThoughts: true });

            const nameStream = parser.getStringProperty("name");
            const result = await nameStream.promise;

            expect(result).toBe("Alice");
            await parser.dispose();
        });

        test("should work with custom thinking tags", async () => {
            const json = '[thought]Processing[/thought]{"value":42}';
            const stream = streamTextInChunks({
                text: json,
                chunkSize: 4,
                interval: 5,
            });
            const parser = new JsonStreamParser(stream, {
                skipThoughts: true,
                thinkingTags: ["[thought]", "[/thought]"],
            });

            const valueStream = parser.getNumberProperty("value");
            const result = await valueStream.promise;

            expect(result).toBe(42);
            await parser.dispose();
        });
    });

    describe("Character Dropping Mismatch Scenarios", () => {
        test("should not drop characters on partial thinking tag mismatch inside JSON string", async () => {
            const json = '{"text": "I love <the color and <thi is nice"}';
            const stream = streamTextInChunks({
                text: json,
                chunkSize: 3,
                interval: 5,
            });
            const parser = new JsonStreamParser(stream, { skipThoughts: true });

            const textStream = parser.getStringProperty("text");
            const result = await textStream.promise;

            expect(result).toBe("I love <the color and <thi is nice");
            await parser.dispose();
        });
    });
});
