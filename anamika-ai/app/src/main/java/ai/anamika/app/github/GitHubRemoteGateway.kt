package ai.anamika.app.github

sealed class RemoteResult {
    data class Success(val message: String) : RemoteResult()
    data class Queued(val message: String) : RemoteResult()
    data class Failure(val message: String) : RemoteResult()
}

interface GitHubRemoteGateway {
    fun push(workspace: String, branch: String, callback: (RemoteResult) -> Unit)
    fun pull(workspace: String, branch: String, callback: (RemoteResult) -> Unit)
    fun createPullRequest(title: String, head: String, base: String, callback: (RemoteResult) -> Unit)
    fun mergePullRequest(number: Int, callback: (RemoteResult) -> Unit)
    fun createIssue(title: String, body: String, callback: (RemoteResult) -> Unit)
    fun createRelease(tag: String, notes: String, callback: (RemoteResult) -> Unit)
    fun runWorkflow(workflow: String, ref: String, callback: (RemoteResult) -> Unit)
}

class BackendGitHubGateway(
    private val queue: RemoteActionQueue
) : GitHubRemoteGateway {

    private fun enqueue(type: String, payload: String, callback: (RemoteResult) -> Unit) {
        queue.enqueue(type, payload)
        callback(
            RemoteResult.Queued(
                "GitHub remote connection abhi configured nahi hai. Action offline queue me save ho gaya."
            )
        )
    }

    override fun push(workspace: String, branch: String, callback: (RemoteResult) -> Unit) =
        enqueue("push", "$workspace|$branch", callback)

    override fun pull(workspace: String, branch: String, callback: (RemoteResult) -> Unit) =
        enqueue("pull", "$workspace|$branch", callback)

    override fun createPullRequest(title: String, head: String, base: String, callback: (RemoteResult) -> Unit) =
        enqueue("create_pr", "$title|$head|$base", callback)

    override fun mergePullRequest(number: Int, callback: (RemoteResult) -> Unit) =
        enqueue("merge_pr", number.toString(), callback)

    override fun createIssue(title: String, body: String, callback: (RemoteResult) -> Unit) =
        enqueue("create_issue", "$title|$body", callback)

    override fun createRelease(tag: String, notes: String, callback: (RemoteResult) -> Unit) =
        enqueue("create_release", "$tag|$notes", callback)

    override fun runWorkflow(workflow: String, ref: String, callback: (RemoteResult) -> Unit) =
        enqueue("run_workflow", "$workflow|$ref", callback)
}
