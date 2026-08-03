/**
 * @license
 * Copyright 2026 Qwen Team
 * SPDX-License-Identifier: Apache-2.0
 */
import type { SdkMcpToolDefinition } from '../../tool.js';
import type { BridgeState } from '../types.js';
/**
 * Collect all MCP tool definitions for the serve-bridge.
 */
export declare function allTools(state: BridgeState): Array<SdkMcpToolDefinition<any>>;
