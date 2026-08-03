/**
 * @license
 * Copyright 2026 Qwen Team
 * SPDX-License-Identifier: Apache-2.0
 */
/**
 * Tool result formatting utilities for MCP responses.
 */
export interface ToolResult {
    content: Array<{
        type: 'text';
        text: string;
    }>;
    isError?: boolean;
}
export declare function formatJsonResult(data: unknown): ToolResult;
export declare function formatToolError(error: Error | string): ToolResult;
