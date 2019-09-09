"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const path = require("path");
const tl = require("vsts-task-lib/task");
var uuidV4 = require('uuid/v4');
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            tl.setResourcePath(path.join(__dirname, 'task.json'));
            let filePath = path.join(__dirname, 'main.ps1');
            // Get inputs.
            let InstrumentationKey = tl.getInput('InstrumentationKey', true);
            let EventName = tl.getInput('EventName', true);
            let SendPipelineMetadata = tl.getBoolInput('SendPipelineMetadata', true);
            let SendPipelineMetadataParameter = '';
            if (SendPipelineMetadata) {
                SendPipelineMetadataParameter = '-SendPipelineMetadata';
            }
            ;
            // Run the script.
            let powershell = tl.tool(tl.which('pwsh') || tl.which('powershell') || tl.which('pwsh', true))
                .arg('-NoLogo')
                .arg('-NoProfile')
                .arg('-NonInteractive')
                .arg('-Command')
                .arg(`. '${filePath.replace("'", "''")}'  -InstrumentationKey '${InstrumentationKey}' -EventName '${EventName}' ${SendPipelineMetadataParameter}`);
            let options = {
                failOnStdErr: false,
                errStream: process.stdout,
                outStream: process.stdout,
                ignoreReturnCode: true
            };
            // Run bash.
            let exitCode = yield powershell.exec(options);
            // Fail on exit code.
            if (exitCode !== 0) {
                tl.setResult(tl.TaskResult.Failed, tl.loc('JS_ExitCode', exitCode));
            }
        }
        catch (err) {
            tl.setResult(tl.TaskResult.Failed, err.message || 'run() failed');
        }
    });
}
run();
