/**
 * @license
 * Copyright 2026 Qwen Team
 * SPDX-License-Identifier: Apache-2.0
 */
/**
 * Shared utility functions for serve-bridge tool handlers.
 */
import type { BridgeState } from './types.js';
/**
 * Resolve the session ID from explicit arg or default state.
 * Returns the session ID or throws a descriptive error.
 */
export declare function resolveSessionId(state: BridgeState, explicitSessionId?: string): string;
/**
 * Create an MCP tool handler that catches errors and returns them as
 * isError responses. Logs error details to stderr for debugging.
 */
export declare function handler<T>(fn: (args: T) => Promise<any>): (args: T, extra: unknown) => Promise<any>;
