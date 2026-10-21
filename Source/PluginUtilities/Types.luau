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
	devDependencies: { [string]: PackageReq }
}
export type Resolve = {
	activated: { [string]: PackageId },
	metadata: { [string]: { realm: Realm, originRealm: Realm } },
	sharedDependencies: { [string]: { [string]: string } },
	serverDependencies: { [string]: { [string]: string } },
	devDependencies: { [string]: { [string]: string } }
}
export type PackageSource = {
	query: (request: PackageReq) -> Result<{ Manifest }>,
	versions: (name: PackageName) -> Result<{ Manifest }>
}
export type RealmPlan = {
	packages: { [string]: string },
	rootLinks: { [string]: string },
	packageLinks: { [string]: { [string]: string } }
}
export type InstallPlan = { shared: RealmPlan, server: RealmPlan, dev: RealmPlan }
export type PlaceManifest = {
	FormatVersion: number,
	Dependencies: { [string]: string }?,
	ServerDependencies: { [string]: string }?
}
export type InstallSummary = { added: number, kept: number, removed: number, id: string?, rootLink: Instance? }
export type InstalledPackage = { alias: string, realm: Realm, requirement: string, id: string }

return { }
