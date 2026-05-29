# MCP Tool Cache Invalidation

## Overview

This document describes how Goose handles cache invalidation for MCP (Model Context Protocol) tools based on their side effects, using the `read_only_hint` annotation from the MCP specification.

## Problem Statement

Goose caches various types of information from MCP servers to improve performance:
- Available tools from each MCP server
- Resources provided by MCP servers
- Tool metadata and capabilities

When an MCP tool executes and modifies state (e.g., deletes files, updates a database, modifies resources), Goose may continue using stale cached information, leading to:
- Incorrect decisions based on outdated context
- Failed operations due to missing resources
- Inconsistent state between the agent's view and reality

## MCP Protocol Support

The MCP protocol provides a standard mechanism to indicate whether a tool has side effects through the `ToolAnnotations` structure:

```rust
pub struct ToolAnnotations {
    pub read_only_hint: Option<bool>,
}
```

- `read_only_hint: Some(true)` - Tool is read-only, does not modify state
- `read_only_hint: Some(false)` - Tool has side effects, modifies state
- `read_only_hint: None` - Unknown, should be treated conservatively

## Current Implementation

### What Works

1. **Permission Management** - Goose correctly uses `read_only_hint` for permission decisions:
   - Tools marked as read-only are auto-approved in SmartApprove mode
   - Tools marked as having side effects require user confirmation
   - Implementation in [`permission_inspector.rs`](../crates/goose/src/permission/permission_inspector.rs)

2. **Annotation Propagation** - Tool annotations flow correctly from MCP servers through the system

### What Was Missing (Now Fixed)

**Cache invalidation after tool execution** - Previously, caches were never invalidated based on tool side effects.

## Solution

### Design Principles

1. **Conservative by Default** - If `read_only_hint` is `None`, assume the tool has side effects
2. **Granular Invalidation** - Only invalidate the tools cache (can be extended to other caches)
3. **Performance Conscious** - Use atomic version counter to minimize lock contention
4. **Transparent** - Add logging for debugging and monitoring

### Implementation

The solution adds cache invalidation logic in [`extension_manager.rs`](../crates/goose/src/agents/extension_manager.rs):

#### 1. Helper Method to Check Tool Side Effects

```rust
/// Check if a tool has side effects based on its read_only_hint annotation.
/// Returns true if the tool modifies state (has side effects).
///
/// Conservative approach:
/// - Returns false only if read_only_hint is explicitly true
/// - Returns true if read_only_hint is false or None (unknown)
async fn tool_has_side_effects(&self, session_id: &str, tool_name: &str) -> bool {
    // Get the tool from cache to check its annotations
    if let Ok(tools) = self.get_all_tools_cached(session_id).await {
        if let Some(tool) = tools.iter().find(|t| t.name == tool_name) {
            if let Some(annotations) = &tool.annotations {
                // Only return false (no side effects) if explicitly marked as read-only
                if let Some(read_only) = annotations.read_only_hint {
                    return !read_only;
                }
            }
        }
    }
    
    // Conservative default: assume side effects if annotation is missing or unknown
    true
}
```

#### 2. Modified dispatch_tool_call Method

The `dispatch_tool_call` method now:
1. Checks if the tool has side effects before execution
2. Captures cache primitives (Arc-wrapped) for the async block
3. Invalidates the cache after successful execution if the tool has side effects

```rust
pub async fn dispatch_tool_call(
    &self,
    ctx: &ToolCallContext,
    tool_call: CallToolRequestParams,
    cancellation_token: CancellationToken,
) -> Result<ToolCallResult> {
    let tool_name_str = tool_call.name.to_string();
    let resolved = self.resolve_tool(&ctx.session_id, &tool_name_str).await?;
    
    // Check if tool has side effects before execution
    let has_side_effects = self.tool_has_side_effects(&ctx.session_id, &tool_name_str).await;
    
    // ... existing validation code ...
    
    // Capture cache invalidation primitives for the async block
    let tools_cache_version = self.tools_cache_version.clone();
    let tools_cache = self.tools_cache.clone();
    let tool_name_for_log = tool_name_str.clone();
    
    let fut = async move {
        // ... execute tool ...
        let mut result = client.call_tool(...).await?;
        
        // ... existing post-processing ...
        
        // Invalidate tools cache if the tool has side effects and executed successfully
        if has_side_effects && result.is_error != Some(true) {
            tracing::debug!(
                "Invalidating tools cache after tool execution: tool={} has_side_effects=true",
                tool_name_for_log
            );
            tools_cache_version.fetch_add(1, Ordering::SeqCst);
            *tools_cache.lock().await = None;
        }
        
        Ok(result)
    };
    
    Ok(ToolCallResult { result: Box::new(fut.boxed()), ... })
}
```

#### 3. Struct Changes

To enable sharing cache primitives across async boundaries, the `ExtensionManager` struct was updated:

```rust
pub struct ExtensionManager {
    extensions: Mutex<HashMap<String, Extension>>,
    context: PlatformExtensionContext,
    provider: SharedProvider,
    tools_cache: Arc<Mutex<Option<Arc<Vec<Tool>>>>>,      // Wrapped in Arc
    tools_cache_version: Arc<AtomicU64>,                   // Wrapped in Arc
    client_name: String,
    capabilities: ExtensionManagerCapabilities,
}
```

This allows the cache primitives to be cloned and moved into the async block without requiring the entire `ExtensionManager` to be cloneable.

## Cache Invalidation Strategy

### Current Scope

The implementation invalidates the **tools cache** when a tool with side effects executes:

```rust
async fn invalidate_tools_cache_and_bump_version(&self) {
    self.tools_cache_version.fetch_add(1, Ordering::SeqCst);
    *self.tools_cache.lock().await = None;
}
```

This ensures that:
- Next tool listing will fetch fresh data from MCP servers
- Tool availability checks use current state
- No stale tool metadata is used

### Future Extensions

The cache invalidation mechanism can be extended to:

1. **Resource Cache** - Invalidate cached resources when tools modify them
2. **Prompt Cache** - Refresh prompts if tools affect prompt generation
3. **Selective Invalidation** - Only invalidate specific resources/tools based on tool metadata
4. **TTL-based Caching** - Add time-to-live for cached items as an additional safety measure

## Configuration

Future work may include configuration options:

```yaml
# goose.yaml (proposed)
mcp:
  cache_invalidation:
    enabled: true
    strategy: conservative  # conservative | aggressive | selective
    ttl_seconds: 300  # Optional TTL for cached items
```

## Monitoring and Debugging

The implementation includes logging for cache invalidation events:

```rust
tracing::debug!(
    "Invalidating tools cache after tool execution: tool={} has_side_effects={}",
    tool_name,
    has_side_effects
);
```

This helps with:
- Debugging cache-related issues
- Understanding tool execution patterns
- Performance monitoring

## Testing

Test scenarios to verify correct behavior:

1. **Read-only tool** - Cache should NOT be invalidated
2. **Write tool** - Cache SHOULD be invalidated
3. **Unknown annotation** - Cache SHOULD be invalidated (conservative)
4. **Multiple tools** - Each tool evaluated independently
5. **Concurrent execution** - Cache invalidation is thread-safe

## References

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [Goose Extension Manager](../crates/goose/src/agents/extension_manager.rs)
- [Permission Inspector](../crates/goose/src/permission/permission_inspector.rs)
- [Tool Execution](../crates/goose/src/agents/tool_execution.rs)