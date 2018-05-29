def call(String srcDir, String destDir, String filter) {
    def status = powershell returnStatus: true, script: "robocopy ${srcDir} ${destDir} ${filter} /E"
    if (status != 1) {
        // robocopy makes extensive use of exit codes. We're interested in checking
        // exit code 1: One of more files were copied successfully.
        return 1
    } else {
        return status
    }
}