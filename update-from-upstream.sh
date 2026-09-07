#!/usr/bin/env bash
# Refresh this mirror from magnolia1234's upstream on GitFlic.
#
#   ./update-from-upstream.sh
#
# Pulls the rolling release artifacts, pins a versioned copy of each, rebuilds
# the source-tree zips straight from the upstream git repos, mirrors the
# paywall filter list, and regenerates release-hashes.txt.
#
# GitFlic has no usable public API (api.gitflic.ru answers 403 without auth), so
# binaries come from the blob/raw endpoint and source comes from git archive.

set -euo pipefail

cd "$(dirname "$0")"

UPLOADS='https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file='
FILTERS='https://gitflic.ru/project/magnolia1234/bypass-paywalls-clean-filters/blob/raw?file=bpc-paywall-filter.txt'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# GitFlic serves an HTML 404 page with a 200-ish body, so check the payload,
# not just the status code.
fetch() {
	local name=$1 url=$2 dest=$3
	printf 'fetching %s\n' "$name" >&2
	curl -fsSL --max-time 180 --retry 3 --retry-delay 2 -o "$tmp/$name" "$url"
	if [ "$(stat -c%s "$tmp/$name")" -lt 20000 ]; then
		printf '%s: upstream returned %s bytes, refusing to overwrite\n' \
			"$name" "$(stat -c%s "$tmp/$name")" >&2
		return 1
	fi
	mv "$tmp/$name" "$dest"
}

# A .crx is a zip behind a signature header, which makes unzip(1) exit 1 even
# when it reads the archive fine. Python's zipfile seeks the central directory
# and handles both container formats.
version_of() {
	python3 - "$1" <<-'PY'
		import json, sys, zipfile
		print(json.loads(zipfile.ZipFile(sys.argv[1]).read("manifest.json"))["version"])
	PY
}

# --- rolling artifacts -------------------------------------------------------
fetch bypass_paywalls_clean-latest.xpi \
	"${UPLOADS}bypass_paywalls_clean-latest.xpi" \
	bypass_paywalls_clean-latest.xpi
fetch bypass-paywalls-chrome-clean-latest.crx \
	"${UPLOADS}bypass-paywalls-chrome-clean-latest.crx" \
	bypass-paywalls-chrome-clean-latest.crx
fetch bypass-paywalls-chrome-clean-android-custom.crx \
	"${UPLOADS}bypass-paywalls-chrome-clean-android-custom.crx" \
	bypass-paywalls-chrome-clean-android-custom.crx

# --- versioned pins ----------------------------------------------------------
# The Firefox and Chrome builds carry independent version numbers, so each is
# read back out of the artifact we just pulled rather than assumed to match.
ff_ver=$(version_of bypass_paywalls_clean-latest.xpi)
cr_ver=$(version_of bypass-paywalls-chrome-clean-latest.crx)
printf 'upstream: firefox %s, chrome %s\n' "$ff_ver" "$cr_ver" >&2

fetch "bypass_paywalls_clean-${ff_ver}.xpi" \
	"${UPLOADS}bypass_paywalls_clean-${ff_ver}.xpi" \
	"bypass_paywalls_clean-${ff_ver}.xpi"
fetch "bypass_paywalls_clean-${ff_ver}-custom.xpi" \
	"${UPLOADS}bypass_paywalls_clean-${ff_ver}-custom.xpi" \
	"bypass_paywalls_clean-${ff_ver}-custom.xpi"
fetch "bypass-paywalls-chrome-clean-${cr_ver}.crx" \
	"${UPLOADS}bypass-paywalls-chrome-clean-${cr_ver}.crx" \
	"bypass-paywalls-chrome-clean-${cr_ver}.crx"

# --- source zips -------------------------------------------------------------
# These are NOT in the upstream git repos. magnolia1234 stripped the source out
# of the public repos on GitFlic -- they now hold only LICENSE, README and
# changelog, plus a not-for-install.txt pointing here. Cloning and running
# git archive gets you a four-file stub that silently replaces a real source
# tree, so both zips come from bpc_uploads like everything else.
fetch bypass-paywalls-firefox-clean-master.zip \
	"${UPLOADS}bypass-paywalls-firefox-clean-master.zip" \
	bypass-paywalls-firefox-clean-master.zip
fetch bypass-paywalls-chrome-clean-master.zip \
	"${UPLOADS}bypass-paywalls-chrome-clean-master.zip" \
	bypass-paywalls-chrome-clean-master.zip

# --- filter list -------------------------------------------------------------
# The only variant that works in Orion on iOS, where the WebExtensions APIs the
# add-on needs (webRequest header rewriting, declarativeNetRequest) are absent.
printf 'fetching bpc-paywall-filter.txt\n' >&2
curl -fsSL --max-time 120 --retry 3 -o "$tmp/filter.txt" "$FILTERS"
grep -q '^! Title: Bypass Paywalls Clean filter' "$tmp/filter.txt"
mv "$tmp/filter.txt" bpc-paywall-filter.txt

# --- hashes ------------------------------------------------------------------
# Modified Time is when this mirror fetched a file, so carry the recorded time
# forward for anything whose hash did not move -- otherwise every archived
# release restamps itself to today on each run and the field means nothing.
printf 'writing release-hashes.txt\n' >&2
python3 - <<'PY'
import hashlib, os, re, time

prev = {}
try:
	with open("release-hashes.txt") as fh:
		for block in fh.read().split("=" * 50):
			name = re.search(r"^Filename\s+: (.+)$", block, re.M)
			digest = re.search(r"^SHA-256\s+: (\w+)$", block, re.M)
			stamp = re.search(r"^Modified Time\s+: (.+)$", block, re.M)
			if name and digest and stamp:
				prev[name.group(1).strip()] = (digest.group(1), stamp.group(1).strip())
except FileNotFoundError:
	pass


def grouped(n):
	return f"{n:,}".replace(",", ".")


files = sorted(f for f in os.listdir(".") if f.endswith((".crx", ".xpi", ".zip")))
out = [
	f"Generated by update-from-upstream.sh on {time.strftime('%-d-%-m-%Y %H:%M:%S')}",
	"Modified Time is when this mirror fetched the file; GitFlic sends no Last-Modified.",
	"",
]
for f in files:
	digest = hashlib.sha256(open(f, "rb").read()).hexdigest()
	if f in prev and prev[f][0] == digest:
		stamp = prev[f][1]
	else:
		stamp = time.strftime("%-d-%-m-%Y %H:%M:%S", time.localtime(os.path.getmtime(f)))
	out += [
		"=" * 50,
		f"Filename          : {f}",
		f"SHA-256           : {digest}",
		f"Modified Time     : {stamp}",
		f"File Size         : {grouped(os.path.getsize(f))}",
		f"Extension         : {f.rsplit('.', 1)[1]}",
		"=" * 50,
		"",
	]
open("release-hashes.txt", "w").write("\n".join(out))
PY

printf 'done\n' >&2
