#!/usr/bin/env bash
set -euo pipefail

need_file(){ test -f "$1" || { echo "Missing required V13 file: $1" >&2; exit 1; }; }
need_text(){ grep -Fq "$2" "$1" || { echo "Missing required V13 capability marker: $2 in $1" >&2; exit 1; }; }

# Core chat / brain / memory / wake
need_file app13/src/main/java/com/anamika/ai/MainActivity.java
need_file app13/src/main/java/com/anamika/ai/BrainCommandEngine.java
need_file app13/src/main/java/com/anamika/ai/NaturalLanguageBrain.java
need_file app13/src/main/java/com/anamika/ai/memory/MemoryStore.java
need_file app13/src/main/java/com/anamika/ai/voice/WakeService.java
need_text app13/src/main/java/com/anamika/ai/MainActivity.java "Create / Add Function"
need_text app13/src/main/java/com/anamika/ai/MainActivity.java "Apply / Repair Direct Code"
need_text app13/src/main/java/com/anamika/ai/MainActivity.java "Self Repair Anamika"
need_text app13/src/main/java/com/anamika/ai/MainActivity.java "Plugins / Accessibility"
need_text app13/src/main/java/com/anamika/ai/MainActivity.java "Deep Blueprint"
need_text app13/src/main/java/com/anamika/ai/MainActivity.java "Research"
need_text app13/src/main/java/com/anamika/ai/MainActivity.java "Wake Listener ON"
need_text app13/src/main/java/com/anamika/ai/MainActivity.java "ChatGPT Connector"

# Self-upgrade / validation / signer / rollback
need_file app13/src/main/java/com/anamika/ai/upgrade/UpgradeCoordinator.java
need_file app13/src/main/java/com/anamika/ai/upgrade/LocalBuildEngine.java
need_file app13/src/main/java/com/anamika/ai/upgrade/SignerVault.java
need_file app13/src/main/java/com/anamika/ai/upgrade/RollbackManager.java
need_text app13/src/main/java/com/anamika/ai/upgrade/UpgradeCoordinator.java "createOrUpgradeFunction"
need_text app13/src/main/java/com/anamika/ai/upgrade/UpgradeCoordinator.java "applyOwnerCode"
need_text app13/src/main/java/com/anamika/ai/upgrade/UpgradeCoordinator.java "buildLatest"

# Phone automation / plugin / messaging
need_file app13/src/main/java/com/anamika/ai/plugins/PluginManagerActivity.java
need_file app13/src/main/java/com/anamika/ai/plugins/AppAutomationAccessibilityService.java
need_file app13/src/main/java/com/anamika/ai/messaging/MessagingAutomationEngine.java
need_file app13/src/main/java/com/anamika/ai/plugins/BlueprintStore.java
need_file app13/src/main/java/com/anamika/ai/research/ResearchStore.java

# ChatGPT remote connector
need_file app13/src/main/java/com/anamika/ai/connector/ChatGptConnectorActivity.java
need_file app13/src/main/java/com/anamika/ai/connector/ChatGptConnectorClient.java
need_file app13/src/main/java/com/anamika/ai/connector/ChatGptConnectorService.java
need_file app13/src/main/java/com/anamika/ai/connector/ChatGptConnectorStore.java
need_file connector/anamika-mcp/server.mjs
need_text connector/anamika-mcp/server.mjs "send_anamika_command"

echo "V13 feature-preservation guard PASS"
