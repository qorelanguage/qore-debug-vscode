'use strict';

import * as vscode from 'vscode';
import { WorkspaceFolder, DebugConfiguration, ProviderResult, CancellationToken } from 'vscode';

export function activate(context: vscode.ExtensionContext) {
	context.subscriptions.push(vscode.commands.registerCommand('extension.qore-debug-vscode.getProgramName', config => {
		return vscode.window.showInputBox({
			placeHolder: "Please enter the name of a Qore file in the workspace folder",
			value: "script.q"
		});
	}));

    // register a configuration provider for 'qore' debug type
	context.subscriptions.push(vscode.debug.registerDebugConfigurationProvider('qore', new QoreConfigurationProvider()));
}

export function deactivate() {
	// nothing to do
}

class QoreConfigurationProvider implements vscode.DebugConfigurationProvider {
    /**
        Massage a debug configuration just before a debug session is being launched,
        e.g. add all missing attributes to the debug configuration.
     */
    resolveDebugConfiguration(folder: WorkspaceFolder | undefined, config: DebugConfiguration, token?: CancellationToken): ProviderResult<DebugConfiguration> {
        // if launch.json is missing or empty
        if (!config.type && !config.request && !config.name) {
            const editor = vscode.window.activeTextEditor;
            if (editor && editor.document.languageId === 'qore' ) {
                config.type = 'qore';
                config.name = 'Launch';
                config.request = 'launch';
                config.program = '${file}';
                config.stopOnEntry = true;
            }
        }

        if (!config.program) {
            return vscode.window.showInformationMessage("Cannot find a program to debug").then(_ => {
                return undefined;	// abort launch
            });
        }

        return config;
    }
}