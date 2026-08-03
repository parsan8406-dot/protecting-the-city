/**
 * @license
 * Copyright 2026 Qwen Team
 * SPDX-License-Identifier: Apache-2.0
 */
import type { McpSdkServerConfigWithInstance } from '../createSdkMcpServer.js';
import type { ServeBridgeMcpServerOptions } from './types.js';
/**
 * Create an MCP server that proxies `qwen serve` HTTP endpoints as MCP tools.
 *
 * @example
 * ```typescript
 * import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
 * import { createServeBridgeMcpServer } from '@qwen-code/sdk';
 *
 * const server = createServeBridgeMcpServer({
 *   daemonUrl: 'http://127.0.0.1:4170',
 *   token: process.env.QWEN_DAEMON_TOKEN,
 * });
 *
 * const transport = new StdioServerTransport();
 * await server.instance.connect(transport);
 * ```
 */
export declare function createServeBridgeMcpServer(opts: ServeBridgeMcpServerOptions): McpSdkServerConfigWithInstance;
