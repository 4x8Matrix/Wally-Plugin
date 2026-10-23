local CargoSemver = require(script.Parent.Parent.Packages.CargoSemver)

export type Realm = "shared" | "server" | "dev"
export type ErrorKind =
	"InvalidRequest"
	| "PackageNotFound"
	| "NoMatchingVersion"
	| "Conflict"
	| "RegistryUnavailable"
	| "DownloadFailed"
	| "BuildFailed"
	| "NameClash"
	| "ManifestUnreadable"
	| "Busy"
	| "CommitFailed"
	| "Unexpected"
export type InstallError = { kind: ErrorKind, message: string, package: string? }
export type Result<T> = { ok: true, value: T } | { ok: false, error: InstallError }
export type PackageName = { scope: string, name: string }
export type PackageId = { name: PackageName, version: CargoSemver.Version }
export type PackageReq = { name: PackageName, versionReq: CargoSemver.VersionReq }
export type Manifest = {
	package: { name: PackageName, version: CargoSemver.Version, realm: Realm, registry: string },
	dependencies: { [string]: PackageReq },
	serverDependencies: { [string]: PackageReq },
	devDependencies: { [string]: PackageReq },
}
export type Resolve = {
	activated: { [string]: PackageId },
	metadata: { [string]: { realm: Realm, originRealm: Realm } },
	sharedDependencies: { [string]: { [string]: string } },
	serverDependencies: { [string]: { [string]: string } },
	devDependencies: { [string]: { [string]: string } },
}
export type PackageSource = {
	query: (request: PackageReq) -> Result<{ Manifest }>,
	versions: (name: PackageName) -> Result<{ Manifest }>,
}
export type RealmPlan = {
	packages: { [string]: string },
	rootLinks: { [string]: string },
	packageLinks: { [string]: { [string]: string } },
}
export type InstallPlan = { shared: RealmPlan, server: RealmPlan, dev: RealmPlan }
export type PlaceManifest = {
	FormatVersion: number,
	Dependencies: { [string]: string }?,
	ServerDependencies: { [string]: string }?,
}
export type InstallSummary = { added: number, kept: number, removed: number, id: string?, rootLink: Instance? }
export type InstalledPackage = { alias: string, realm: Realm, requirement: string, id: string }
export type WidgetLayout = {
	widthClass: "xs" | "s" | "m" | "l",
	surface: "sheet" | "inline" | "full" | "side" | "strip" | "stripLine",
	strip: boolean,
	stackedTabs: boolean,
	panelWidth: number,
	rowClass: "xs" | "s" | "m" | "l",
}
export type SearchResult = { scope: string, name: string, description: string, version: string }
export type Progress = { operation: string, step: "resolving" | "downloading" | "writing", done: number, total: number }
export type FormField = "name" | "version" | "general"
export type DataValue = boolean | number | string | DataNull | DataArray | DataMap
export type DataNull = { kind: "null" }
export type DataArray = { kind: "array", items: { DataValue } }
export type DataMap = { kind: "map", entries: { { key: DataValue, value: DataValue } } }
export type ParsedValue = { explicit: boolean, variant: string, value: any, holdsNil: boolean, source: DataValue }
export type ParsedAttribute = { name: string, parsed: ParsedValue }
export type BuildError = { path: string, message: string }
export type BuildResult<T> = { ok: true, value: T } | { ok: false, error: BuildError }
export type SnapshotContext = {
	syncRules: { SyncRule },
	ignoreRules: { IgnoreRule },
	emitLegacyScripts: boolean,
}
export type SyncRule = {
	matches: (path: string) -> boolean,
	excludes: ((path: string) -> boolean)?,
	use: string,
	suffix: string?,
}
export type IgnoreRule = { folder: string, matches: (path: string) -> boolean, negated: boolean }
export type Snapshot = {
	name: string,
	className: string,
	properties: { [string]: any },
	children: { Snapshot },
	id: string?,
	model: Instance?,
	path: string,
}
export type DecodedFile = { className: string, properties: { [string]: any } }
export type MetaFile = {
	schema: string?,
	id: string?,
	className: string?,
	properties: DataMap,
	attributes: DataMap,
}
export type JsonModel = {
	name: string?,
	className: string,
	id: string?,
	properties: DataMap,
	attributes: DataMap,
	children: { JsonModel },
}
export type StructField = { name: string, presence: "required" | "optional" | "defaulted" }
export type StructShape = { name: string, fields: { StructField }, denyUnknownFields: boolean }
export type IgnoreGlob = { matches: (path: string) -> boolean, negated: boolean }
export type ProjectPath = { path: string, optional: boolean }
export type ProjectNode = {
	className: string?,
	id: string?,
	path: ProjectPath?,
	properties: DataMap,
	attributes: DataMap,
	children: { { name: string, node: ProjectNode } },
}
export type ProjectFile = {
	name: string?,
	tree: ProjectNode,
	emitLegacyScripts: boolean?,
	globIgnorePaths: { IgnoreGlob },
	syncRules: { SyncRule },
}

return {}
