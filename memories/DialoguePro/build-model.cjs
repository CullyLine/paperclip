#!/usr/bin/env node
// Generates DialoguePro.rbxmx — a Roblox Model containing the full
// DialoguePro runtime ready to insert into ReplicatedStorage.
//
// Run:  node build-model.cjs
//
// Output structure inside the model:
//   DialoguePro (Folder)
//   ├── DialoguePro      (ModuleScript)
//   ├── DialogueParser      (ModuleScript)
//   ├── DialogueRunner      (ModuleScript)
//   ├── DialogueUI          (ModuleScript)
//   ├── Theme               (ModuleScript)
//   └── Types               (ModuleScript)

const fs = require("fs");
const path = require("path");

const DIR = __dirname;

const runtimeModules = [
	{ name: "DialoguePro", file: "DialoguePro.lua" },
	{ name: "DialogueParser", file: "DialogueParser.lua" },
	{ name: "DialogueRunner", file: "DialogueRunner.lua" },
	{ name: "DialogueUI",     file: "DialogueUI.lua" },
	{ name: "Theme",          file: "Theme.lua" },
	{ name: "Types",          file: "Types.lua" },
];

const demoScripts = [
	{
		name: "VerySimpleExampleDialog",
		file: path.join("Example", "VerySimpleExampleDialog.local.luau"),
		class: "LocalScript",
	},
];

const readmeText = `--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║                    DIALOGUEPRO                          ║
    ║              Professional dialogue system for Roblox          ║
    ╚══════════════════════════════════════════════════════════════╝

    SETUP
    ─────
    1. Drag the entire "DialoguePro" folder into ReplicatedStorage.

    QUICK START
    ───────────
    1. Look at the "VerySimpleExampleDialog" LocalScript in the Example folder.
       It walks you through everything step by step.

    2. Drag "VerySimpleExampleDialog" into StarterPlayerScripts to try it out.
       It's disabled by default — enable it once it's in StarterPlayerScripts.

    3. Note: the example won't do anything on its own. It needs NPC models
       in Workspace with matching names (like "Guard", "Shopkeeper", etc.)
       with a Head part. The script creates ProximityPrompts automatically.
       The example script explains all of this.

    VISUAL DESIGNER (FREE PLUGIN)
    ──────────────────────────────
    Don't want to type out dialogue by hand? Get the free
    "Dialogue Designer" plugin from the Creator Store.
    It gives you a node-based visual editor for creating and editing
    dialogue trees, then exports them in the correct format.

    WHAT'S INCLUDED
    ────────────────
    DialoguePro     — Main API (require this to start)
    DialogueParser     — Converts text format into dialogue trees
    DialogueRunner     — Manages traversal, conditions, branching
    DialogueUI         — Full ScreenGui with typewriter, choices, portraits
    Theme              — Customizable look and feel
    Types              — Type definitions

    Example/
      VerySimpleExampleDialog — Step-by-step beginner examples
]]`;

let refId = 0;
function nextRef() { return `RBX${refId++}`; }

function escapeXml(str) {
	return str.replace(/\]\]>/g, "]]]]><![CDATA[>");
}

function xmlModuleScript(name, source, indent = "\t\t") {
	const ref = nextRef();
	return `${indent}<Item class="ModuleScript" referent="${ref}">
${indent}\t<Properties>
${indent}\t\t<string name="Name">${name}</string>
${indent}\t\t<ProtectedString name="Source"><![CDATA[${escapeXml(source)}]]></ProtectedString>
${indent}\t</Properties>
${indent}</Item>`;
}

function xmlScript(className, name, source, disabled, indent = "\t\t\t") {
	const ref = nextRef();
	return `${indent}<Item class="${className}" referent="${ref}">
${indent}\t<Properties>
${indent}\t\t<string name="Name">${name}</string>
${indent}\t\t<bool name="Disabled">${disabled ? "true" : "false"}</bool>
${indent}\t\t<ProtectedString name="Source"><![CDATA[${escapeXml(source)}]]></ProtectedString>
${indent}\t</Properties>
${indent}</Item>`;
}

// Build README item
const readmeRef = nextRef();
const readmeItem = `\t\t<Item class="Script" referent="${readmeRef}">
\t\t\t<Properties>
\t\t\t\t<string name="Name">README</string>
\t\t\t\t<bool name="Disabled">true</bool>
\t\t\t\t<ProtectedString name="Source"><![CDATA[${escapeXml(readmeText)}]]></ProtectedString>
\t\t\t</Properties>
\t\t</Item>`;

// Build runtime module items
const moduleItems = [];
moduleItems.push(readmeItem);
for (const mod of runtimeModules) {
	const source = fs.readFileSync(path.join(DIR, mod.file), "utf8");
	moduleItems.push(xmlModuleScript(mod.name, source));
}

// Build Demo folder with example scripts
const demoFolderRef = nextRef();
const demoItems = [];
for (const script of demoScripts) {
	const filePath = path.join(DIR, script.file);
	if (!fs.existsSync(filePath)) {
		console.warn(`Warning: ${script.file} not found, skipping`);
		continue;
	}
	const source = fs.readFileSync(filePath, "utf8");
	const disabled = !script.enabled;
	demoItems.push(xmlScript(script.class, script.name, source, disabled));
}

let demoFolder = "";
if (demoItems.length > 0) {
	demoFolder = `
		<Item class="Folder" referent="${demoFolderRef}">
			<Properties>
				<string name="Name">Example</string>
			</Properties>
${demoItems.join("\n")}
		</Item>`;
}

const rootRef = nextRef();
const xml = `<roblox version="4">
	<External>null</External>
	<External>nil</External>
	<Item class="Folder" referent="${rootRef}">
		<Properties>
			<string name="Name">DialoguePro</string>
		</Properties>
${moduleItems.join("\n")}${demoFolder}
	</Item>
</roblox>
`;

const outPath = path.join(DIR, "DialoguePro.rbxmx");
fs.writeFileSync(outPath, xml, "utf8");

const sizeKB = (fs.statSync(outPath).size / 1024).toFixed(1);
console.log(`Built ${outPath} (${sizeKB} KB)`);
console.log(`Contains ${runtimeModules.length} modules` + (demoItems.length > 0 ? ` + Example folder (${demoItems.length} scripts)` : ``));

const delivDir = path.resolve(DIR, "..", "Deliverables");
if (!fs.existsSync(delivDir)) fs.mkdirSync(delivDir, { recursive: true });

const modelDest = path.join(delivDir, "DialoguePro.rbxmx");
fs.copyFileSync(outPath, modelDest);
console.log(`Copied model  -> ${modelDest}`);

const designerSrc = path.join(DIR, "Designer", "DialogueDesigner.rbxmx");
if (fs.existsSync(designerSrc)) {
	const designerDest = path.join(delivDir, "DialogueDesigner.rbxmx");
	fs.copyFileSync(designerSrc, designerDest);
	console.log(`Copied plugin -> ${designerDest}`);
} else {
	console.warn(`Warning: Designer plugin not found at ${designerSrc}`);
}

console.log(`\nTo use: drag DialoguePro.rbxmx into ReplicatedStorage in Roblox Studio`);
console.log(`Or upload to Creator Marketplace as a Model.`);
