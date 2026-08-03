/**
 * @license
 * Copyright 2025 Qwen Team
 * SPDX-License-Identifier: Apache-2.0
 */
import type { DaemonEvent } from './types.js';
/**
 * A JSON-RPC 2.0 notification (no `id` field). ACP transports receive
 * these on the wire and must convert them to `DaemonEvent`.
 */
export interface JsonRpcNotification {
    jsonrpc: '2.0';
    method: string;
    params?: Record<string, unknown>;
}
/**
 * Convert an ACP JSON-RPC notification into a `DaemonEvent`.
 *
 * Mapping rules:
 *   - `session/update` notification → `DaemonEvent` with the `type`
 *     field read from `params.type`. The full `params` object becomes
 *     `data`.
 *   - `_qwen/notify` notification → `DaemonEvent` with `type` and
 *     `data` read from `params`.
 *   - Notifications with `method` matching a known daemon event type
 *     directly (e.g. `memory_changed`, `agent_changed`) are passed
 *     through with `params` as `data`.
 *
 * Returns `undefined` for notifications that don't map to any known
 * `DaemonEvent` shape (the caller silently drops them).
 */
export declare function denormalizeAcpNotification(notification: JsonRpcNotification): DaemonEvent | undefined;
/**
 * Filter a mixed stream of ACP notifications, yielding only
 * `DaemonEvent`s for the specified session. Events without a
 * `sessionId` field in their data are considered workspace-scoped
 * and are always yielded (they fan out to all sessions).
 */
export declare function filterEventsBySession(events: Iterable<DaemonEvent>, sessionId: string): Generator<DaemonEvent>;
/**
 * Reset the synthetic id counter. Exposed for testing only.
 * @internal
 */
export declare function _resetSyntheticIdCounter(): void;
