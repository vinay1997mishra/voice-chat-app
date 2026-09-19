package ai.anamika.app.github

enum class GitHubCapability {
    CREATE_REPOSITORY,
    READ_REPOSITORY,
    UPDATE_REPOSITORY_SETTINGS,
    DELETE_REPOSITORY,

    CREATE_FILE,
    READ_FILE,
    UPDATE_FILE,
    DELETE_FILE,

    CREATE_BRANCH,
    READ_BRANCH,
    DELETE_BRANCH,
    COMPARE_COMMITS,
    CREATE_COMMIT,
    READ_COMMIT,
    CREATE_TAG,
    DELETE_TAG,

    PUSH,
    PULL,
    FETCH_REMOTE,

    CREATE_PULL_REQUEST,
    READ_PULL_REQUEST,
    UPDATE_PULL_REQUEST,
    REVIEW_PULL_REQUEST,
    MERGE_PULL_REQUEST,
    CLOSE_PULL_REQUEST,

    CREATE_ISSUE,
    READ_ISSUE,
    UPDATE_ISSUE,
    COMMENT_ISSUE,
    CLOSE_ISSUE,
    MANAGE_LABELS,
    MANAGE_ASSIGNEES,

    CREATE_RELEASE,
    READ_RELEASE,
    UPDATE_RELEASE,
    DELETE_RELEASE,
    UPLOAD_RELEASE_ASSET,

    RUN_WORKFLOW,
    READ_WORKFLOW_RUN,
    CANCEL_WORKFLOW,
    RERUN_WORKFLOW,
    READ_WORKFLOW_LOGS,
    DOWNLOAD_ARTIFACT,

    READ_COMMIT_STATUS,
    READ_SECURITY_SCAN,
    MANAGE_COLLABORATORS,
    MANAGE_SECRETS
}

object GitHubCapabilityCatalog {
    val offlineLocalEquivalents = setOf(
        GitHubCapability.CREATE_REPOSITORY,
        GitHubCapability.READ_REPOSITORY,
        GitHubCapability.CREATE_FILE,
        GitHubCapability.READ_FILE,
        GitHubCapability.UPDATE_FILE,
        GitHubCapability.DELETE_FILE,
        GitHubCapability.CREATE_BRANCH,
        GitHubCapability.READ_BRANCH,
        GitHubCapability.DELETE_BRANCH,
        GitHubCapability.COMPARE_COMMITS,
        GitHubCapability.CREATE_COMMIT,
        GitHubCapability.READ_COMMIT,
        GitHubCapability.CREATE_TAG,
        GitHubCapability.DELETE_TAG,
        GitHubCapability.FETCH_REMOTE
    )

    val requiresGitHubService = GitHubCapability.entries.toSet() - offlineLocalEquivalents
}
