/*---------------------------------------------------------
 * Copyright (C) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------*/

'use strict';

import * as vscode from 'vscode';

const initialConfigurations = {
	version: '0.2.0',
	configurations: [
		{
			type: 'qore',
			request: 'launch',
			name: 'Qore Debug',
			program: '${workspaceRoot}/script.q',
			stopOnEntry: true
		}
	]
};

export function activate(context: vscode.ExtensionContext) {

	context.subscriptions.push(vscode.commands.registerCommand('extension.qore-debug.getProgramName', config => {
		return vscode.window.showInputBox({
			placeHolder: "Please enter the name of a Qore file in the workspace folder",
			value: "script.q"
		});
	}));

	context.subscriptions.push(vscode.commands.registerCommand('extension.qore-debug.provideInitialConfigurations', () => {
		return [
			'// Use IntelliSense to learn about possible Qore debug attributes.',
			'// Hover to view descriptions of existing attributes.',
			JSON.stringify(initialConfigurations, null, '\t')
		].join('\n');
	}));
}

export function deactivate() {
	// nothing to do
}
