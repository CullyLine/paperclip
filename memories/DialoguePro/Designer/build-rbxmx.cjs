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

const now = new Date();
const stamp = `${now.getMonth()+1}/${now.getDate()} ${now.getHours()}:${String(now.getMinutes()).padStart(2,"0")}`;
const pluginSource = fs.readFileSync(path.join(DIR, "Plugin.server.lua"), "utf8")
	.replace("BUILD_TIMESTAMP", stamp);

let refId = 0;
function nextRef() { return `RBX${refId++}`; }

function xmlItem(className, name, source, children) {
	const ref = nextRef();
	const childXml = children ? "\n" + children.join("\n") : "";
	return `		<Item class="${className}" referent="${ref}">
			<Properties>
				<string name="Name">${name}</string>
				<ProtectedString name="Source"><![CDATA[${source}]]></ProtectedString>
			</Properties>${childXml}
		</Item>`;
}

const moduleItems = [];
for (const mod of modules) {
	const source = fs.readFileSync(path.join(DIR, mod.file), "utf8");
	moduleItems.push(xmlItem(mod.class, mod.name, source));
}

const pluginItem = xmlItem("Script", "DialogueDesigner", pluginSource, moduleItems);

const xml = `<roblox version="4">
	<External>null</External>
	<External>nil</External>
${pluginItem}
</roblox>
`;

const fileName = "DialogueDesigner.rbxmx";

const pluginsDir = path.join(process.env.LOCALAPPDATA || "", "Roblox", "Plugins");
if (fs.existsSync(pluginsDir)) {
	const pluginPath = path.join(pluginsDir, fileName);
	fs.writeFileSync(pluginPath, xml, "utf8");
	const sizeKB = (fs.statSync(pluginPath).size / 1024).toFixed(1);
	console.log(`Installed plugin -> ${pluginPath} (${sizeKB} KB)`);
} else {
	console.warn(`Warning: Roblox plugins folder not found at ${pluginsDir}`);
	const fallback = path.join(DIR, fileName);
	fs.writeFileSync(fallback, xml, "utf8");
	console.log(`Built ${fallback} (fallback — plugins folder missing)`);
}

const localCopy = path.join(DIR, fileName);
fs.writeFileSync(localCopy, xml, "utf8");

const delivDir = path.resolve(DIR, "..", "..", "Deliverables");
if (!fs.existsSync(delivDir)) fs.mkdirSync(delivDir, { recursive: true });
const delivPath = path.join(delivDir, fileName);
fs.copyFileSync(localCopy, delivPath);
console.log(`Copied to Deliverables -> ${delivPath}`);
