'use strict';

import * as vscode from 'vscode';
import { WorkspaceFolder, DebugConfiguration/*, DebugAdapterExecutable*/, ProviderResult, CancellationToken } from 'vscode';

// TODO: currently in vscode.proposed
/**
 * Represents a debug adapter executable and optional arguments passed to it.
 */
class DebugAdapterExecutable {
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


export function activate(context: vscode.ExtensionContext) {
	context.subscriptions.push(vscode.commands.registerCommand('extension.qore-debug-vscode.getFilename', config => {
		return vscode.window.showInputBox({
			placeHolder: "Please enter the name of a Qore file in the workspace folder",
			value: "script.q"
		});
	}));
	context.subscriptions.push(vscode.commands.registerCommand('extension.qore-debug-vscode.getConnection', config => {
		return vscode.window.showInputBox({
			placeHolder: "Please enter the connection name to Qore debug server",
			value: "ws://localhost:8001/debug"
		});
	}));
	context.subscriptions.push(vscode.commands.registerCommand('extension.qore-debug-vscode.getProgram', config => {
		return vscode.window.showInputBox({
			placeHolder: "Please enter the name of a Qore program or program id",
			value: "my-job"
		});
	}));

    // register a configuration provider for 'qore' debug type
	context.subscriptions.push(vscode.debug.registerDebugConfigurationProvider('qore', new QoreConfigurationProvider()));
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
     */
    resolveDebugConfiguration(folder: WorkspaceFolder | undefined, config: DebugConfiguration, token?: CancellationToken): ProviderResult<DebugConfiguration> {
        console.log("resolveDebugConfiguration(folder: "+folder+", config:"+config+")");
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

        //this._args = ["/home/tma/work/qore/qore-debug-vscode/qvscdbg"];
        this._args = ["./qvscdbgx"];
        if (config.request === 'attach') {
            if (!config.connection) {
                return vscode.window.showInformationMessage("Connection string not specified").then(_ => {
                    return undefined;	// abort launch
                });
            }
            this._args.push("--append "+config.connection);
            if (!config.program) {
                return vscode.window.showInformationMessage("Program name or id is not specified").then(_ => {
                    return undefined;	// abort launch
                });
            }
            if (config.proxy) {
                this._args.push("--proxy " + config.proxy);
            }
            if (typeof config.maxRedir !== "undefined") {
                this._args.push("--max-redir "+config.maxRedir);
            }
            if (typeof config.timeout !== "undefined") {
                this._args.push("--timeout "+config.timeout);
            }
            if (typeof config.connTimeout !== "undefined") {
                this._args.push("--conn-timeout "+config.connTimeout);
            }
            if (typeof config.respTimeout !== "undefined") {
                this._args.push("--resp-timeout "+config.respTimeout);
            }
        } else {
            if (!config.program) {
                return vscode.window.showInformationMessage("Cannot find a program to debug").then(_ => {
                    return undefined;	// abort launch
                });
            }
            if (config.define) {
                for (let _s in config.define) {
                    this._args.push("--define " + _s);
                }
            }
            if (config.parseOptions) {
                for (let _s in config.parseOptions) {
                    this._args.push("--set-parse-options " + _s);
                }
            }
            if (config.timeZone) {
                this._args.push("--time-zone " + config.timeZone);
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
            this._args.push("--logger-filename"+config.logFilename)
        }
        if (config.appendToLog) {
            this._args.push("--append-to-log");
        }
        this._executable = "qore";   // no slash to have relative path
        return config;
    }

    debugAdapterExecutable?(folder: WorkspaceFolder | undefined, token?: CancellationToken): ProviderResult<DebugAdapterExecutable> {
        console.log("debugAdapterExecutable(folder: "+folder+")");
        console.log("Qore debug adapter: "+this._executable+" args:"+this._args);
        return new DebugAdapterExecutable(this._executable, this._args);
    }
}