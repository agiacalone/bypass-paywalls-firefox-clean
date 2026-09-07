# Bypass Paywalls Clean

A personal mirror of [magnolia1234's](https://gitflic.ru/user/magnolia1234) Bypass Paywalls Clean
releases, so the builds I install are pinned somewhere I control and the paywall filter list is
served from a host that is fast from the US.

> [!NOTE]
> This is a mirror, not the project. Bug reports, new-site requests and support belong upstream:
> [Firefox](https://gitflic.ru/project/magnolia1234/bypass-paywalls-firefox-clean) ·
> [Chrome](https://gitflic.ru/project/magnolia1234/bypass-paywalls-chrome-clean) ·
> [filters](https://gitflic.ru/project/magnolia1234/bypass-paywalls-clean-filters) ·
> [release uploads](https://gitflic.ru/project/magnolia1234/bpc_uploads).

## Which file do I want

| File | For |
|---|---|
| `bypass_paywalls_clean-latest.xpi` | Firefox and forks. Signed by Mozilla, installs by drag-and-drop onto a tab |
| `bypass_paywalls_clean-<version>-custom.xpi` | Same site list, but asks for host permissions on all sites up front instead of ~970 named ones |
| `bypass-paywalls-chrome-clean-latest.crx` | Chrome, Edge, Brave, Vivaldi |
| `bypass-paywalls-chrome-clean-android-custom.crx` | Kiwi and other Chromium-on-Android browsers |
| `*-master.zip` | Unpacked source, for `chrome://extensions` → *Load unpacked* |
| `bpc-paywall-filter.txt` | Ad-blocker filter list. Covers fewer sites than the add-on, but needs no extension support at all |

Versioned copies are kept alongside the rolling `-latest` ones so a working build can be pinned
when a release regresses.

> [!TIP]
> Firefox and Chrome version numbers drift apart. A Chrome release ships the day it is cut, while
> the Firefox `.xpi` waits on Mozilla's signing, so the signed add-on usually trails the source
> tree by one release. Read the version out of the artifact, don't assume the two match.

## Orion on iOS

Orion can install `.xpi` files (⋯ → Settings → Extensions → toggle Firefox extensions on, then
⋯ → Extensions → **+**), and the add-on will load. Most of it will not do anything.

The add-on is Manifest V2 and leans on `webRequest` to rewrite request headers, spoofing the
Referer and a Googlebot user agent. On iOS, Apple's restrictions mean Orion supports **none** of
`webRequest.HttpHeaders` — 36 of its 50 components are unsupported there, against 31 fully
supported on macOS. The bypasses that survive are the ones built on `tabs.executeScript` and
`cookies.remove`, both of which Orion does support on iOS. Everything header-based silently
does nothing.

> [!IMPORTANT]
> On iOS, add the filter list instead. It compiles to native WebKit content rules, so none of the
> WebExtensions gaps apply.
>
> ```
> https://raw.githubusercontent.com/agiacalone/bypass-paywalls-clean/main/bpc-paywall-filter.txt
> ```
>
> ⋯ → Settings → Content Blockers → Manage Content Blocker → **Add New**, paste, name it, Done.
> Refresh later from the same screen with **Update Now**.

The Chrome `.crx` is not an option in Orion on either platform: it needs `declarativeNetRequest`,
which Orion supports nowhere, and `offscreen`, which isn't in its API table at all.

## Refreshing the mirror

```sh
./update-from-upstream.sh
```

Pulls the rolling artifacts, reads each one's version out of its own `manifest.json` and pins a
versioned copy, fetches both source zips and the filter list, then regenerates
`release-hashes.txt`. Safe to re-run; nothing but the generated-on line changes if upstream
hasn't moved.

> [!WARNING]
> Don't rebuild the `-master.zip` files with `git archive` against the upstream repos. The source
> was stripped out of them — all that's left is a LICENSE, a README, a changelog and a
> `not-for-install.txt` pointing at the uploads project. Cloning gets you a four-file stub that
> looks like a successful update. Both zips come from `bpc_uploads` for that reason.

`release-hashes.txt` records a SHA-256 per file. *Modified Time* is when this mirror fetched the
file, not when upstream built it: GitFlic sends no `Last-Modified`, and the archives are built
with zeroed zip timestamps. Files whose hash hasn't moved keep the time they were first recorded.

## Disclaimer

Mirrored for personal use and archival. The upstream project provides this software for
educational purposes, as is, without warranty of any kind.
