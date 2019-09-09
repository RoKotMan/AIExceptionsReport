import fs = require('fs');
import path = require('path');
import os = require('os');
import tl = require('vsts-task-lib/task');
import tr = require('vsts-task-lib/toolrunner');
var uuidV4 = require('uuid/v4');

async function run() {
    try {
        tl.setResourcePath(path.join(__dirname, 'task.json'));
        let filePath = path.join(__dirname, 'main.ps1');
        // Get inputs.
        let InstrumentationKey: string = tl.getInput('InstrumentationKey', true);
        let EventName: string = tl.getInput('EventName', true);
        let SendPipelineMetadata: boolean = tl.getBoolInput('SendPipelineMetadata', true);
        let SendPipelineMetadataParameter: string = ''
        if (SendPipelineMetadata) {
            SendPipelineMetadataParameter = '-SendPipelineMetadata'
        };
        // Run the script.
        let powershell = tl.tool(tl.which('pwsh') || tl.which('powershell') || tl.which('pwsh', true))
            .arg('-NoLogo')
            .arg('-NoProfile')
            .arg('-NonInteractive')
            .arg('-Command')
            .arg(`. '${filePath.replace("'", "''")}'  -InstrumentationKey '${InstrumentationKey}' -EventName '${EventName}' ${SendPipelineMetadataParameter}`);
        let options = <tr.IExecOptions>{
            failOnStdErr: false,
            errStream: process.stdout, // Direct all output to STDOUT, otherwise the output may appear out
            outStream: process.stdout, // of order since Node buffers it's own STDOUT but not STDERR.
            ignoreReturnCode: true
        };


        // Run bash.
        let exitCode: number = await powershell.exec(options);

        // Fail on exit code.
        if (exitCode !== 0) {
            tl.setResult(tl.TaskResult.Failed, tl.loc('JS_ExitCode', exitCode));
        }
    }
    catch (err) {
        tl.setResult(tl.TaskResult.Failed, err.message || 'run() failed');
    }
}

run();
