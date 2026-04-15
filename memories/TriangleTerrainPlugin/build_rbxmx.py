import os

src_dir = r'F:\CODE STUFF\Paperclip\memories\TriangleTerrainPlugin\src'

files = {}
for name in ['Plugin.server', 'Signal', 'Theme', 'TerrainState', 'TriangleEngine',
             'NodeManager', 'InputHandler', 'AutoTriangulate', 'WidgetUI']:
    ext = '.luau'
    fname = name + ext
    with open(os.path.join(src_dir, fname), 'r', encoding='utf-8') as f:
        files[name] = f.read()

parts = []
parts.append('<roblox version="4">')
parts.append('\t<External>null</External>')
parts.append('\t<External>nil</External>')

parts.append('\t\t<Item class="Script" referent="RBX0">')
parts.append('\t\t\t<Properties>')
parts.append('\t\t\t\t<string name="Name">TriangleTerrainPlugin</string>')
parts.append('\t\t\t\t<ProtectedString name="Source"><![CDATA[' + files['Plugin.server'] + ']]></ProtectedString>')
parts.append('\t\t\t</Properties>')

modules = ['Signal', 'Theme', 'TerrainState', 'TriangleEngine', 'NodeManager',
           'InputHandler', 'AutoTriangulate', 'WidgetUI']

for i, name in enumerate(modules):
    ref = f'RBX{i+1}'
    parts.append(f'\t\t<Item class="ModuleScript" referent="{ref}">')
    parts.append('\t\t\t<Properties>')
    parts.append(f'\t\t\t\t<string name="Name">{name}</string>')
    parts.append('\t\t\t\t<ProtectedString name="Source"><![CDATA[' + files[name] + ']]></ProtectedString>')
    parts.append('\t\t\t</Properties>')
    parts.append('\t\t</Item>')

parts.append('\t\t</Item>')
parts.append('</roblox>')

output = '\n'.join(parts)

plugins_path = r'C:\Users\lineb\AppData\Local\Roblox\Plugins'
os.makedirs(plugins_path, exist_ok=True)
out_file = os.path.join(plugins_path, 'TriangleTerrainPlugin.rbxmx')
with open(out_file, 'w', encoding='utf-8') as f:
    f.write(output)

print(f'Written {len(output)} bytes to {out_file}')
print(f'Modules: {len(modules)}')

backup = os.path.join(src_dir, '..', 'TriangleTerrainPlugin.rbxmx')
with open(backup, 'w', encoding='utf-8') as f:
    f.write(output)
print(f'Backup copy at {backup}')
