'use strict';

import * as vscode from 'vscode';
import { WorkspaceFolder, DebugConfiguration/*, DebugAdapterExecutable*/, ProviderResult, CancellationToken } from 'vscode';
//import { IDebugAdapter, IAdapterExecutable } from 'vs/workbench/parts/debug/common/debug';

// TODO: currently in vscode.proposed
/**
 * Represents a debug adapter executable and optional arguments passed to it.
 */
class DebugAdapterExecutable /* implements vscode.IAdapterExecutable */ {
    /**
     * The command path of the debug adapter executable.
     * A command must be either an absolute path or the name of an executable looked up via the PATH environment variable.
     * The special value 'node' will be mapped to VS Code's built-in node runtime.
     */
    readonly command: string;

    /**
     * Optional arguments passed to the debug adapter executable.
     */
    readonly args?: string[];

    /**
     * Create a new debug adapter specification.
     */
    constructor(command: string, args?: string[]) {
        this.command = command;
        this.args = args;
    }
}

// tutorial abouut "=>" https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/Arrow_functions
export function activate(context: vscode.ExtensionContext) {
	context.subscriptions.push(vscode.commands.registerCommand('extension.qore-debug-vscode.getFilename', config => {
        console.log("extension.qore-debug-vscode.getFilename(config:"+JSON.stringify(config)+")");
        // show input box is invoded async in executeCommandVariables so result of command is a Thenable object
		return vscode.window.showInputBox({
            //prompt: "",
			placeHolder: "Please enter the name of a Qore file in the workspace folder",
			value: "script.q"
        });
	}));
	context.subscriptions.push(vscode.commands.registerCommand('extension.qore-debug-vscode.getConnection', config => {
        console.log("extension.qore-debug-vscode.getConnection(config:"+JSON.stringify(config)+")");
		return vscode.window.showInputBox({
			placeHolder: "Please enter the connection name to Qore debug server",
			value: "ws://localhost:8001/debug"
		});
	}));
	context.subscriptions.push(vscode.commands.registerCommand('extension.qore-debug-vscode.getProgram', config => {
        console.log("extension.qore-debug-vscode.getProgram(config:"+JSON.stringify(config)+")");
		return vscode.window.showInputBox({
			placeHolder: "Please enter the name of a Qore program or program id",
			value: "my-job"
		});
	}));

    // register a configuration provider for 'qore' debug type
    context.subscriptions.push(vscode.debug.registerDebugConfigurationProvider('qore', new QoreConfigurationProvider()));
    
    context.subscriptions.push(vscode.debug.onDidStartDebugSession(session => {
        console.log("extension.qore-debug-vscode.onDidStartDebugSession(session:"+JSON.stringify(session)+")");        
    }));
    context.subscriptions.push(vscode.debug.onDidTerminateDebugSession(session => {
        console.log("extension.qore-debug-vscode.onDidTerminateDebugSession(session:"+JSON.stringify(session)+")");        
    }));
    // loaded scripts
    //vscode.window.registerTreeDataProvider('extension.qore-debug-vscode.loadedScriptsExplorer', new loadedScripts_1.LoadedScriptsProvider(context))
    //context.subscriptions.push(vscode.commands.registerCommand('extension.qore-debug-vscode.pickLoadedScript', loadedScripts_1.pickLoadedScript));
    //context.subscriptions.push(vscode.commands.registerCommand('extension.qore-debug-vscode.openScript', (session, source) => loadedScripts_1.openS
    
}

export function deactivate() {
	// nothing to do
}

class QoreConfigurationProvider implements vscode.DebugConfigurationProvider {
    private _executable: string;
    private _args: string[];
    /**
        Massage a debug configuration just before a debug session is being launched,
        e.g. add all missing attributes to the debug configuration.
        Commands ${command:xxx} are invoked by vscode and value is substituted
     */
    resolveDebugConfiguration(folder: WorkspaceFolder | undefined, config: DebugConfiguration, token?: CancellationToken): ProviderResult<DebugConfiguration> {
        console.log("resolveDebugConfiguration(folder: "+JSON.stringify(folder)+", config:"+JSON.stringify(config)+", token:"+JSON.stringify(token)+")");
        // if launch.json is missing or empty
        if (!config.type && !config.request && !config.name) {
            const editor = vscode.window.activeTextEditor;
            if (editor && editor.document.languageId === 'qore' ) {
                config.type = 'qore';
                config.name = 'Launch';
                config.request = 'launch';
                config.program = '${file}';
                config.stopOnEntry = true;  // TODO: not yet supported
            }
        }
        this._args = ["/home/tma/work/qore/qore-debug-vscode/qvscdbg"];
        //this._args = ["./qvscdbg"];  // qore CWD is not in this folder!
        if (config.request === 'attach') {
            if (!config.connection) {
                return vscode.window.showInformationMessage("Connection string not specified").then(_ => {
                    return undefined;	// abort launch
                });
            }
            this._args.push("--attach");
            this._args.push(config.connection);
            if (!config.program) {
                return vscode.window.showInformationMessage("Program name or id is not specified").then(_ => {
                    return undefined;	// abort launch
                });
            }
            if (config.proxy) {
                this._args.push("--proxy");
                this._args.push(config.proxy);
            }
            if (typeof config.maxRedir !== "undefined") {
                this._args.push("--max-redir");
                this._args.push(config.maxRedir);
            }
            if (typeof config.timeout !== "undefined") {
                this._args.push("--timeout");
                this._args.push(config.timeout);
            }
            if (typeof config.connTimeout !== "undefined") {
                this._args.push("--conn-timeout");
                this._args.push(config.connTimeout);
            }
            if (typeof config.respTimeout !== "undefined") {
                this._args.push("--resp-timeout");
                this._args.push(config.respTimeout);
            }
        } else {
            if (!config.program) {
                return vscode.window.showInformationMessage("Cannot find a program to debug").then(_ => {
                    return undefined;	// abort launch
                });
            }
            if (config.define) {
                for (let _s in config.define) {
                    this._args.push("--define");
                    this._args.push(config.define[_s]);
                }
            }
            if (config.parseOptions) {
                for (let _s in config.parseOptions) {
                    this._args.push("--set-parse-option");
                    this._args.push(config.parseOptions[_s]);
                }
            }
            if (config.timeZone) {
                this._args.push("--time-zone");
                this._args.push(config.timeZone);
            }
        }
        if (config.verbosity > 0) {
            let i;
            for (i=0; i<config.verbosity; i++) {
                this._args.push("-v");
            }
        }
        if (config.fullException) {
            this._args.push("--full-exception");
        }
        if (config.logFilename) {
            this._args.push("--logger-filename");
            this._args.push(config.logFilename);
        }
        if (config.appendToLog) {
            this._args.push("--append-to-log");
        }
        this._executable = "qore";   // no slash to have relative path
        console.log("config:"+JSON.stringify(config));
        return config;
    }

    debugAdapterExecutable?(folder: WorkspaceFolder | undefined, token?: CancellationToken): ProviderResult<DebugAdapterExecutable> {
        console.log("debugAdapterExecutable(folder: "+JSON.stringify(folder)+")");
        console.log("Qore debug adapter: "+this._executable+" args:"+this._args);
        return new DebugAdapterExecutable(this._executable, this._args);   }
}