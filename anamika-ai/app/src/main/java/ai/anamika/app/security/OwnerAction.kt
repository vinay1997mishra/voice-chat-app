package ai.anamika.app.security

enum class RiskLevel {
    NORMAL,
    PROTECTED,
    CRITICAL,
    ULTRA_CRITICAL
}

enum class OwnerAction(val risk: RiskLevel) {
    READ_LOCAL_REPO(RiskLevel.NORMAL),
    WRITE_LOCAL_REPO(RiskLevel.PROTECTED),
    WRITE_LOCAL_FILE(RiskLevel.PROTECTED),
    DELETE_LOCAL_FILE(RiskLevel.CRITICAL),
    CREATE_BRANCH(RiskLevel.PROTECTED),
    COMMIT_CODE(RiskLevel.PROTECTED),
    MERGE_BRANCH(RiskLevel.CRITICAL),
    CREATE_TAG(RiskLevel.CRITICAL),
    REMOTE_PUSH(RiskLevel.CRITICAL),
    REMOTE_PULL(RiskLevel.PROTECTED),
    CREATE_PULL_REQUEST(RiskLevel.CRITICAL),
    MERGE_PULL_REQUEST(RiskLevel.ULTRA_CRITICAL),
    MANAGE_ISSUES(RiskLevel.PROTECTED),
    MANAGE_RELEASES(RiskLevel.CRITICAL),
    RUN_WORKFLOW(RiskLevel.CRITICAL),
    CHANGE_REPOSITORY_SETTINGS(RiskLevel.ULTRA_CRITICAL),
    CHANGE_SECRETS(RiskLevel.ULTRA_CRITICAL),
    DELETE_REPOSITORY(RiskLevel.ULTRA_CRITICAL),
    CONFIGURE_BUILD_SERVER(RiskLevel.PROTECTED),
    BUILD_APK(RiskLevel.CRITICAL),
    INSTALL_APK(RiskLevel.CRITICAL),
    CHANGE_INTERNET_POLICY(RiskLevel.PROTECTED),
    AUTHORIZE_OTHER_APP(RiskLevel.CRITICAL),
    CONTROL_OTHER_APP(RiskLevel.PROTECTED),
    OBSERVE_OTHER_APP(RiskLevel.PROTECTED),
    SELF_UPDATE(RiskLevel.CRITICAL)
}

object OwnerPermissionPolicy {
    fun requiresDeviceCredential(action: OwnerAction): Boolean =
        action.risk != RiskLevel.NORMAL

    fun requiresSecondConfirmation(action: OwnerAction): Boolean =
        action.risk == RiskLevel.ULTRA_CRITICAL
}
