# PoB2 custom Power Report

Based on the official Path of Building 2 **v0.23.1** release.

- Right-click a Power Report row to ignore that node in the current build.
- Click **Ignored (N)** above the report to select a node, **Focus on tree**, **Restore / Unignore**, or **Restore All**.
- Focus closes the popup, centers the active tree, and highlights the node for five seconds. Nodes absent from the active tree remain listed and restorable.
- Ignoring and restoring immediately refresh the full calculated candidate list, retaining the current report filter and sort. Fresh calculations also respect the ignored IDs.
- Save the build normally. Ignored IDs and fallback names are saved inside its `Tree/IgnoredPowerNodes` XML section and shared by all tree variants of that build. They do not affect allocations, paths, calculation values, or other builds.

## Portable version

Extract the complete ZIP into its own folder and launch `Path of Building-PoE2.exe`. Builds and settings live in that portable folder. Existing builds can be opened or copied into its `Builds` folder.

The package uses the official portable release, retaining the upstream executable, LuaJIT, graphics libraries, and game data. Only the custom Lua files and delivery metadata are added or replaced. No performance benchmark is performed.

The `custom.cfg` marker protects the custom files from the official in-app updater. **Custom Releases** opens this fork's releases page. Keep that marker in place and install future custom ZIPs into a separate folder before copying your builds/settings. Saving a custom build with unmodified upstream PoB2 may discard the additional ignored-node XML section; use the custom version to retain it.

## Repository maintenance

- Local checkout: `D:\Codex\PoE2\PathOfBuilding-PoE2`
- `origin`: `https://github.com/buivydas1-stack/PathOfBuilding-PoE2.git`
- `upstream`: `https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2.git`
- Published custom branch: `codex/pob2-customizations`
- Initial stable base: `v0.23.1` (`7d6f530c`)

Keep upstream branches clean. Review new upstream releases on a temporary integration branch, merge the selected stable release into the custom branch after functional checks, and publish a new custom tag. Avoid rebasing commits already used by a published portable release. The weekly Codex task reports upstream changes and recommends integration; it does not perform merges.

## Verification and packaging

Run `tools/Test-CustomPowerReport.ps1` from Windows PowerShell or PowerShell 7. It uses the upstream LuaJIT DLL and headless wrapper for functional checks, including actual mouse handlers, XML round-trips, popup bounds/actions, stale node IDs, and update protection.

Run `tools/Build-CustomPortable.ps1 -UpstreamZip <official-v0.23.1-portable.zip> -OutputDirectory <new-empty-output-directory>`. The script validates the pinned upstream ZIP checksum, overlays the five custom Lua files, verifies all other upstream files byte-for-byte, and creates a ZIP with SHA-256 and provenance metadata. When upgrading upstream, update the pinned release and checksum after review.
