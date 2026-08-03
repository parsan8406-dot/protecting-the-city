/**
 * @license
 * Copyright 2026 Qwen Team
 * SPDX-License-Identifier: Apache-2.0
 */
/**
 * Persistent SSE connection lifecycle management.
 */
import type { BridgeState, PromptCollector } from './types.js';
/**
 * Create a new PromptCollector that resolves when called.
 */
export declare function createPromptCollector(): PromptCollector;
/**
 * Start a persistent SSE subscription for a session.
 * Collects agent_message_chunk events into the active PromptCollector.
 */
export declare function startEventStream(state: BridgeState, sessionId: string): void;
/**
 * Stop the persistent SSE subscription for a session.
 */
export declare function stopEventStream(state: BridgeState, sessionId: string): void;
/**
 * Start a periodic cleanup timer that removes idle SSE streams.
 * Returns a cleanup function to stop the timer (call on server shutdown).
 */
export declare function startSessionCleanup(state: BridgeState): () => void;
