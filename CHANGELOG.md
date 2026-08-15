# Changelog

## [0.3.2](https://github.com/aydabd/muximate/compare/v0.3.1...v0.3.2) (2026-08-15)


### Bug Fixes

* **release:** decouple dev releases from tags ([#27](https://github.com/aydabd/muximate/issues/27)) ([434fd0e](https://github.com/aydabd/muximate/commit/434fd0e0769cc73e74e9a4586080894e731070eb))
* **release:** make metadata PRs policy compliant ([9b034d3](https://github.com/aydabd/muximate/commit/9b034d36878a582c50c4f1ec18a5c0f5c1857f07))
* **release:** use prerelease versioning strategy ([a4ccc41](https://github.com/aydabd/muximate/commit/a4ccc41b5d09bc9532ee73ffdcdd6a34254fb58a))

## [0.3.1-dev.2](https://github.com/aydabd/muximate/compare/v0.3.0-dev.2...v0.3.1-dev.2) (2026-08-15)


### Bug Fixes

* **release:** retry metadata synchronization safely ([9c5b397](https://github.com/aydabd/muximate/commit/9c5b39764763e94d2dfcd350488e8e25316a7125))

## [0.3.0-dev.2](https://github.com/aydabd/muximate/compare/v0.2.0-dev.2...v0.3.0-dev.2) (2026-08-15)


### Features

* **release:** allow explicit prerelease version input ([7ba12f5](https://github.com/aydabd/muximate/commit/7ba12f56c77a76df52b001c80a9e8b5e7b1a417c))
* **release:** skip consumed prerelease lines ([b893741](https://github.com/aydabd/muximate/commit/b8937414410a30477e42b90c1ba1ab26d61d4c80))


### Bug Fixes

* **ci:** isolate config tests across runners ([d203054](https://github.com/aydabd/muximate/commit/d203054308ddd25c2f56c95a488c9026165af0db))
* explain stale github keychain credentials ([946b2e2](https://github.com/aydabd/muximate/commit/946b2e2300088ebd864ea1fa783a115ae319b4b0))
* **release:** honor conventional minor bumps ([07a604f](https://github.com/aydabd/muximate/commit/07a604fd086d51bdd5727545b431de48d1a9f63b))
* **release:** honor manual manifest versions ([71b7201](https://github.com/aydabd/muximate/commit/71b720175376d035be29535bd24aea386c2bff06))
* **release:** pin the 0.3.0 development prerelease ([8d55c67](https://github.com/aydabd/muximate/commit/8d55c67924a52646619598b233b2cabf65b84c37))
* **release:** reject duplicate manual versions ([4a1ef5f](https://github.com/aydabd/muximate/commit/4a1ef5f48e1027f6cae7d3086277dd39e8cb03e8))
* route gh login through cmux profiles ([1793fa4](https://github.com/aydabd/muximate/commit/1793fa470cd64b6a3181aa7b10096ef3d187fc9b))
* support non-interactive cmux browser routing ([be12d2c](https://github.com/aydabd/muximate/commit/be12d2c8907056101b4d2b8e39b1c4c8a572a845))
* use active platform browser for gh login ([a73d4d0](https://github.com/aydabd/muximate/commit/a73d4d0d49952d95098c8adaac948c726bc60d45))

## [0.2.0-dev.2](https://github.com/aydabd/muximate/compare/v0.2.0-dev.1...v0.2.0-dev.2) (2026-08-14)


### Features

* add reviewed production promotion flow ([f6efa25](https://github.com/aydabd/muximate/commit/f6efa250f3c16c7034761937e82740d6aa84848d))


### Bug Fixes

* require one production approval ([a4f9250](https://github.com/aydabd/muximate/commit/a4f9250eec4fbac908caf7624b6f67aef211d498))

## [0.2.0-dev.1](https://github.com/aydabd/muximate/compare/v0.2.0-dev.0...v0.2.0-dev.1) (2026-08-14)


### Features

* attest release archives ([f7cc692](https://github.com/aydabd/muximate/commit/f7cc692dbf665549cf65c8e72e034dbe51af91cc))
* make configuration and e2e tests portable ([e2e0925](https://github.com/aydabd/muximate/commit/e2e0925d249452cb5fe771998f27a014d542fe69))


### Bug Fixes

* accept signed-off trailer final newline ([083a97c](https://github.com/aydabd/muximate/commit/083a97c0439c0cc1ac01c852a0891d4c2480a4fe))
* bootstrap first development release ([#8](https://github.com/aydabd/muximate/issues/8)) ([ec9f036](https://github.com/aydabd/muximate/commit/ec9f0360960d70ea409afc0b3a52ebdaf35d13bc))
* configure release pull request title ([#13](https://github.com/aydabd/muximate/issues/13)) ([0a72f37](https://github.com/aydabd/muximate/commit/0a72f3724559ca9210026b5d3b31e9e6292c0cc4))
* constrain production promotion sources ([939f0d8](https://github.com/aydabd/muximate/commit/939f0d896c8d7eb84a471bc7af8e2e04ea0f60f5))
* correction of namin and removing old description ([5e3ff5e](https://github.com/aydabd/muximate/commit/5e3ff5e374a89a9fe65ed3b6b12d400dcac59945))
* declare release-please root package ([#7](https://github.com/aydabd/muximate/issues/7)) ([11fc40c](https://github.com/aydabd/muximate/commit/11fc40ca8d46f32533c9d33d32665ff20a1bf000))
* enforce immutable tool and config values ([d9c86c8](https://github.com/aydabd/muximate/commit/d9c86c89cd8c1761de07777fa84dba864979f815))
* enforce semantic version tags globally ([e349bbe](https://github.com/aydabd/muximate/commit/e349bbe22bd76850110d83058a15b9aeded66240))
* harden local filesystem writes ([d924d44](https://github.com/aydabd/muximate/commit/d924d448960370f4ed612060b82912f394d654ff))
* isolate Windows shellcheck tool install ([da88a40](https://github.com/aydabd/muximate/commit/da88a40fd4a7b22e03e1902a67938b58ff6eb564))
* keep repository tag ruleset API compatible ([c343ac5](https://github.com/aydabd/muximate/commit/c343ac516bf2320221b8c15e594e4dc6b4a822ff))
* keep tag ruleset compatible with release token ([1d9ea2a](https://github.com/aydabd/muximate/commit/1d9ea2a9ae84c58e7bd29665a80d20f292330927))
* make zsh prompt integration idempotent ([52ef10a](https://github.com/aydabd/muximate/commit/52ef10a2663461e4ce6378b7742637cfd8d3a22e))
* pin security-sensitive tooling ([23e03db](https://github.com/aydabd/muximate/commit/23e03db105dc94178f547e2f43ba07abeaad6518))
* publish development prereleases directly ([20ce6a3](https://github.com/aydabd/muximate/commit/20ce6a3845a2ac345c692253e7558f242da760c6))
* refresh local activation and workspace initialization ([165070c](https://github.com/aydabd/muximate/commit/165070c5ee496ea5b54c4d071819a29a80d51982))
* reject unsafe configuration input ([241ce82](https://github.com/aydabd/muximate/commit/241ce8264bbdac0f8cd52bfe4c6fcd884e15bc95))
* restore PR policy and release automation ([#6](https://github.com/aydabd/muximate/issues/6)) ([dae8652](https://github.com/aydabd/muximate/commit/dae8652f65ed6bbf5aab020c9ebc4f3b17c5871c))
* seed numbered development prerelease ([d31de44](https://github.com/aydabd/muximate/commit/d31de4491b6eaf470e2c15da81849103104dc345))
* set release-please signoff identity ([#12](https://github.com/aydabd/muximate/issues/12)) ([cd2add3](https://github.com/aydabd/muximate/commit/cd2add359356fdede819cfdfb43533a71e588f01))
* stabilize cross-platform CI and dependency updates ([d8fb7f3](https://github.com/aydabd/muximate/commit/d8fb7f3e20cc0efa826d77dab60bcba9a3de52f9))
* use release-please pull request flow ([#9](https://github.com/aydabd/muximate/issues/9)) ([997a94d](https://github.com/aydabd/muximate/commit/997a94d3315bc4db3b8725455e9bd4998d65e206))
* use valid renovate lock schedule ([9049692](https://github.com/aydabd/muximate/commit/904969272677c30dba7fb2993f8858727476305f))
* use Windows smoke tests without unsupported Bats lock ([db3cffb](https://github.com/aydabd/muximate/commit/db3cffb7b62406f3597b05c499146acafe9991af))
* validate generated release pull requests ([#11](https://github.com/aydabd/muximate/issues/11)) ([a47fd61](https://github.com/aydabd/muximate/commit/a47fd617ba8544a99597808c3ac3b0bec6b4236a))

## [0.2.0-dev](https://github.com/aydabd/muximate/compare/v0.1.0...v0.2.0-dev) (2026-08-14)


### Features

* attest release archives ([f7cc692](https://github.com/aydabd/muximate/commit/f7cc692dbf665549cf65c8e72e034dbe51af91cc))
* make configuration and e2e tests portable ([e2e0925](https://github.com/aydabd/muximate/commit/e2e0925d249452cb5fe771998f27a014d542fe69))


### Bug Fixes

* accept signed-off trailer final newline ([083a97c](https://github.com/aydabd/muximate/commit/083a97c0439c0cc1ac01c852a0891d4c2480a4fe))
* bootstrap first development release ([#8](https://github.com/aydabd/muximate/issues/8)) ([ec9f036](https://github.com/aydabd/muximate/commit/ec9f0360960d70ea409afc0b3a52ebdaf35d13bc))
* configure release pull request title ([#13](https://github.com/aydabd/muximate/issues/13)) ([0a72f37](https://github.com/aydabd/muximate/commit/0a72f3724559ca9210026b5d3b31e9e6292c0cc4))
* constrain production promotion sources ([939f0d8](https://github.com/aydabd/muximate/commit/939f0d896c8d7eb84a471bc7af8e2e04ea0f60f5))
* correction of namin and removing old description ([5e3ff5e](https://github.com/aydabd/muximate/commit/5e3ff5e374a89a9fe65ed3b6b12d400dcac59945))
* declare release-please root package ([#7](https://github.com/aydabd/muximate/issues/7)) ([11fc40c](https://github.com/aydabd/muximate/commit/11fc40ca8d46f32533c9d33d32665ff20a1bf000))
* enforce immutable tool and config values ([d9c86c8](https://github.com/aydabd/muximate/commit/d9c86c89cd8c1761de07777fa84dba864979f815))
* enforce semantic version tags globally ([e349bbe](https://github.com/aydabd/muximate/commit/e349bbe22bd76850110d83058a15b9aeded66240))
* harden local filesystem writes ([d924d44](https://github.com/aydabd/muximate/commit/d924d448960370f4ed612060b82912f394d654ff))
* isolate Windows shellcheck tool install ([da88a40](https://github.com/aydabd/muximate/commit/da88a40fd4a7b22e03e1902a67938b58ff6eb564))
* keep repository tag ruleset API compatible ([c343ac5](https://github.com/aydabd/muximate/commit/c343ac516bf2320221b8c15e594e4dc6b4a822ff))
* keep tag ruleset compatible with release token ([1d9ea2a](https://github.com/aydabd/muximate/commit/1d9ea2a9ae84c58e7bd29665a80d20f292330927))
* make zsh prompt integration idempotent ([52ef10a](https://github.com/aydabd/muximate/commit/52ef10a2663461e4ce6378b7742637cfd8d3a22e))
* pin security-sensitive tooling ([23e03db](https://github.com/aydabd/muximate/commit/23e03db105dc94178f547e2f43ba07abeaad6518))
* publish development prereleases directly ([20ce6a3](https://github.com/aydabd/muximate/commit/20ce6a3845a2ac345c692253e7558f242da760c6))
* refresh local activation and workspace initialization ([165070c](https://github.com/aydabd/muximate/commit/165070c5ee496ea5b54c4d071819a29a80d51982))
* reject unsafe configuration input ([241ce82](https://github.com/aydabd/muximate/commit/241ce8264bbdac0f8cd52bfe4c6fcd884e15bc95))
* restore PR policy and release automation ([#6](https://github.com/aydabd/muximate/issues/6)) ([dae8652](https://github.com/aydabd/muximate/commit/dae8652f65ed6bbf5aab020c9ebc4f3b17c5871c))
* set release-please signoff identity ([#12](https://github.com/aydabd/muximate/issues/12)) ([cd2add3](https://github.com/aydabd/muximate/commit/cd2add359356fdede819cfdfb43533a71e588f01))
* stabilize cross-platform CI and dependency updates ([d8fb7f3](https://github.com/aydabd/muximate/commit/d8fb7f3e20cc0efa826d77dab60bcba9a3de52f9))
* use release-please pull request flow ([#9](https://github.com/aydabd/muximate/issues/9)) ([997a94d](https://github.com/aydabd/muximate/commit/997a94d3315bc4db3b8725455e9bd4998d65e206))
* use valid renovate lock schedule ([9049692](https://github.com/aydabd/muximate/commit/904969272677c30dba7fb2993f8858727476305f))
* use Windows smoke tests without unsupported Bats lock ([db3cffb](https://github.com/aydabd/muximate/commit/db3cffb7b62406f3597b05c499146acafe9991af))
* validate generated release pull requests ([#11](https://github.com/aydabd/muximate/issues/11)) ([a47fd61](https://github.com/aydabd/muximate/commit/a47fd617ba8544a99597808c3ac3b0bec6b4236a))

## Changelog

All notable changes to muximate are documented here.
