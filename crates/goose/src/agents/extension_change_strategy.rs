use serde::{Deserialize, Serialize};
use std::fmt;
use std::str::FromStr;

/// Strategy for handling LLM context when extensions are enabled or disabled
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ExtensionChangeStrategy {
    /// Trigger conversation compaction to regenerate system prompt with updated tools (default)
    Rebuild,
    /// Clear conversation history entirely when extensions change
    Clear,
    /// Add a system message explaining tool changes but keep history
    Notify,
}

impl Default for ExtensionChangeStrategy {
    fn default() -> Self {
        Self::Rebuild
    }
}

impl fmt::Display for ExtensionChangeStrategy {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Rebuild => write!(f, "rebuild"),
            Self::Clear => write!(f, "clear"),
            Self::Notify => write!(f, "notify"),
        }
    }
}

impl FromStr for ExtensionChangeStrategy {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "rebuild" => Ok(Self::Rebuild),
            "clear" => Ok(Self::Clear),
            "notify" => Ok(Self::Notify),
            _ => Err(format!(
                "Invalid extension change strategy: '{}'. Valid options are: rebuild, clear, notify",
                s
            )),
        }
    }
}

impl ExtensionChangeStrategy {
    /// Get the strategy from config, falling back to default if not set or invalid
    pub fn from_config() -> Self {
        crate::config::Config::global()
            .get_goose_extension_change_strategy()
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or_default()
    }

    /// Get a description of what this strategy does
    pub fn description(&self) -> &'static str {
        match self {
            Self::Rebuild => "Compact conversation and regenerate system prompt with updated tools",
            Self::Clear => "Start fresh conversation when extensions change",
            Self::Notify => "Add message about changes but keep history",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_strategy() {
        assert_eq!("rebuild".parse::<ExtensionChangeStrategy>().unwrap(), ExtensionChangeStrategy::Rebuild);
        assert_eq!("clear".parse::<ExtensionChangeStrategy>().unwrap(), ExtensionChangeStrategy::Clear);
        assert_eq!("notify".parse::<ExtensionChangeStrategy>().unwrap(), ExtensionChangeStrategy::Notify);
        assert_eq!("REBUILD".parse::<ExtensionChangeStrategy>().unwrap(), ExtensionChangeStrategy::Rebuild);
        assert!("invalid".parse::<ExtensionChangeStrategy>().is_err());
    }

    #[test]
    fn test_display() {
        assert_eq!(ExtensionChangeStrategy::Rebuild.to_string(), "rebuild");
        assert_eq!(ExtensionChangeStrategy::Clear.to_string(), "clear");
        assert_eq!(ExtensionChangeStrategy::Notify.to_string(), "notify");
    }

    #[test]
    fn test_default() {
        assert_eq!(ExtensionChangeStrategy::default(), ExtensionChangeStrategy::Rebuild);
    }
}

// Made with Bob
