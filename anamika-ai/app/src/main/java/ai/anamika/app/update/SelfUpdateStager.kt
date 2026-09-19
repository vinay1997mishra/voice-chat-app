package ai.anamika.app.update

import ai.anamika.app.workspace.WorkspaceFileManager
import org.json.JSONObject

data class StagedSelfUpdate(
    val sourcePackage: String,
    val featureMapPath: String,
    val requestedChanges: String,
    val stagedPath: String
)

class SelfUpdateStager(
    private val files: WorkspaceFileManager
) {
    fun stage(
        workspace: String,
        sourcePackage: String,
        featureMapPath: String,
        requestedChanges: String
    ): StagedSelfUpdate {
        require(sourcePackage.isNotBlank()) { "Source package missing" }
        require(requestedChanges.isNotBlank()) { "Requested changes missing" }

        val payload = JSONObject()
            .put("sourcePackage", sourcePackage)
            .put("featureMapPath", featureMapPath)
            .put("requestedChanges", requestedChanges)
            .put("status", "STAGED_NOT_INSTALLED")
            .put("requiresOwnerApproval", true)
            .put("requiresTests", true)
            .put("requiresApkBuild", true)
            .toString(2)

        val path = "self-update/pending-update.json"
        files.writeText(workspace, path, payload)

        return StagedSelfUpdate(
            sourcePackage = sourcePackage,
            featureMapPath = featureMapPath,
            requestedChanges = requestedChanges,
            stagedPath = path
        )
    }
}
