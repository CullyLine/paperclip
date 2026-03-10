#!/usr/bin/env node
// Generates DialogueDesigner.rbxmx from the Lua source files.
// Run: node build-rbxmx.js

const fs = require("fs");
const path = require("path");

const DIR = __dirname;

const modules = [
	{ name: "DesignerTheme", file: "DesignerTheme.lua", class: "ModuleScript" },
	{ name: "AppState",      file: "AppState.lua",      class: "ModuleScript" },
	{ name: "Serializer",    file: "Serializer.lua",     class: "ModuleScript" },
	{ name: "NodeWidget",    file: "NodeWidget.lua",     class: "ModuleScript" },
	{ name: "ConnectionRenderer", file: "ConnectionRenderer.lua", class: "ModuleScript" },
	{ name: "Canvas",        file: "Canvas.lua",         class: "ModuleScript" },
	{ name: "PropertyPanel", file: "PropertyPanel.lua",  class: "ModuleScript" },
	{ name: "Toolbar",       file: "Toolbar.lua",        class: "ModuleScript" },
];

const pluginSource = fs.readFileSync(path.join(DIR, "Plugin.server.lua"), "utf8");

let refId = 0;
function nextRef() { return `RBX${refId++}`; }

function xmlItem(className, name, source) {
	const ref = nextRef();
	return `		<Item class="${className}" referent="${ref}">
			<Properties>
				<string name="Name">${name}</string>
				<ProtectedString name="Source"><![CDATA[${source}]]></ProtectedString>
			</Properties>
		</Item>`;
}

const folderRef = nextRef();
const items = [];

items.push(xmlItem("Script", "Plugin", pluginSource));

for (const mod of modules) {
	const source = fs.readFileSync(path.join(DIR, mod.file), "utf8");
	items.push(xmlItem(mod.class, mod.name, source));
}

const xml = `<roblox version="4">
	<External>null</External>
	<External>nil</External>
	<Item class="Folder" referent="${folderRef}">
		<Properties>
			<string name="Name">DialogueDesigner</string>
		</Properties>
${items.join("\n")}
	</Item>
</roblox>
`;

const outPath = path.join(DIR, "DialogueDesigner.rbxmx");
fs.writeFileSync(outPath, xml, "utf8");

const sizeKB = (fs.statSync(outPath).size / 1024).toFixed(1);
console.log(`Built ${outPath} (${sizeKB} KB)`);
