use goose::agents::ExtensionChangeStrategy;
use std::str::FromStr;

#[tokio::test]
async fn test_extension_change_strategy_from_config() {
    // Test default strategy
    let strategy = ExtensionChangeStrategy::from_config();
    assert_eq!(strategy, ExtensionChangeStrategy::Rebuild);
}

#[tokio::test]
async fn test_extension_change_strategy_parsing() {
    assert_eq!(
        ExtensionChangeStrategy::from_str("rebuild").unwrap(),
        ExtensionChangeStrategy::Rebuild
    );
    assert_eq!(
        ExtensionChangeStrategy::from_str("clear").unwrap(),
        ExtensionChangeStrategy::Clear
    );
    assert_eq!(
        ExtensionChangeStrategy::from_str("notify").unwrap(),
        ExtensionChangeStrategy::Notify
    );
    assert_eq!(
        ExtensionChangeStrategy::from_str("REBUILD").unwrap(),
        ExtensionChangeStrategy::Rebuild
    );
    assert!(ExtensionChangeStrategy::from_str("invalid").is_err());
}

#[test]
fn test_extension_change_strategy_display() {
    assert_eq!(ExtensionChangeStrategy::Rebuild.to_string(), "rebuild");
    assert_eq!(ExtensionChangeStrategy::Clear.to_string(), "clear");
    assert_eq!(ExtensionChangeStrategy::Notify.to_string(), "notify");
}

#[test]
fn test_extension_change_strategy_default() {
    assert_eq!(
        ExtensionChangeStrategy::default(),
        ExtensionChangeStrategy::Rebuild
    );
}

#[test]
fn test_extension_change_strategy_description() {
    assert!(ExtensionChangeStrategy::Rebuild
        .description()
        .contains("Compact"));
    assert!(ExtensionChangeStrategy::Clear
        .description()
        .contains("fresh"));
    assert!(ExtensionChangeStrategy::Notify
        .description()
        .contains("message"));
}

// Made with Bob
