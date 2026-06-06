#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const siteRoot = path.join(repoRoot, "website");
const requiredFiles = [
  "index.html",
  "donate.html",
  "styles.css",
  "scripts.js",
  "vercel.json",
  "assets/main_logo.png",
  "assets/hero-screenshot.jpg",
];

const failures = [];
let checkedReferences = 0;

function fail(message) {
  failures.push(message);
}

function exists(relativePath) {
  return fs.existsSync(path.join(siteRoot, relativePath));
}

function readSiteFile(relativePath) {
  return fs.readFileSync(path.join(siteRoot, relativePath), "utf8");
}

function isExternalReference(value) {
  return (
    value === "" ||
    value.startsWith("#") ||
    value.startsWith("http://") ||
    value.startsWith("https://") ||
    value.startsWith("mailto:") ||
    value.startsWith("tel:") ||
    value.startsWith("data:") ||
    value.startsWith("//") ||
    value.startsWith("javascript:")
  );
}

function splitReference(rawValue) {
  const [withoutHash, hash = ""] = rawValue.split("#", 2);
  const [target] = withoutHash.split("?", 1);
  return { target, hash };
}

function htmlIds(relativePath) {
  const html = readSiteFile(relativePath);
  return new Set([...html.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]));
}

function checkHash(relativePath, hash, sourcePath, rawValue) {
  if (!hash) return;
  if (!relativePath.endsWith(".html")) return;
  if (!htmlIds(relativePath).has(hash)) {
    fail(`${sourcePath}: ${rawValue} points to missing #${hash} in ${relativePath}`);
  }
}

function normalizeTarget(sourcePath, rawValue) {
  const { target, hash } = splitReference(rawValue);
  if (!target) {
    return { relativePath: sourcePath, hash };
  }

  const sourceDir = path.dirname(path.join(siteRoot, sourcePath));
  const absoluteTarget = target.startsWith("/")
    ? path.join(siteRoot, target)
    : path.resolve(sourceDir, target);

  let relativePath = path.relative(siteRoot, absoluteTarget);
  if (relativePath === "") {
    relativePath = "index.html";
  }
  if (relativePath.endsWith(path.sep)) {
    relativePath = path.join(relativePath, "index.html");
  }
  return { relativePath, hash };
}

function checkReference(sourcePath, rawValue) {
  if (isExternalReference(rawValue)) {
    if (rawValue.startsWith("#")) {
      checkHash(sourcePath, rawValue.slice(1), sourcePath, rawValue);
    }
    return;
  }

  checkedReferences += 1;
  const { relativePath, hash } = normalizeTarget(sourcePath, rawValue);
  if (relativePath.startsWith("..")) {
    fail(`${sourcePath}: ${rawValue} resolves outside website/`);
    return;
  }
  if (!exists(relativePath)) {
    fail(`${sourcePath}: ${rawValue} resolves to missing ${relativePath}`);
    return;
  }
  checkHash(relativePath, hash, sourcePath, rawValue);
}

for (const relativePath of requiredFiles) {
  if (!exists(relativePath)) {
    fail(`missing required website file: ${relativePath}`);
  }
}

try {
  JSON.parse(readSiteFile("vercel.json"));
} catch (error) {
  fail(`website/vercel.json is invalid JSON: ${error.message}`);
}

for (const relativePath of ["index.html", "donate.html"]) {
  if (!exists(relativePath)) continue;
  const html = readSiteFile(relativePath);
  const attributePattern = /\b(?:href|src)="([^"]+)"/g;
  for (const match of html.matchAll(attributePattern)) {
    checkReference(relativePath, match[1]);
  }
  const contentPattern = /\bcontent="(\.?\/[^"]+)"/g;
  for (const match of html.matchAll(contentPattern)) {
    checkReference(relativePath, match[1]);
  }
}

if (exists("styles.css")) {
  const css = readSiteFile("styles.css");
  const urlPattern = /url\(([^)]+)\)/g;
  for (const match of css.matchAll(urlPattern)) {
    const rawValue = match[1].trim().replace(/^['"]|['"]$/g, "");
    checkReference("styles.css", rawValue);
  }
}

if (failures.length > 0) {
  console.error("Website validation failed:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(`Website validation passed (${checkedReferences} local references checked).`);
