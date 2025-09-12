# JVM Option Env Var Precedence Report

Generated: 2025-09-12 19:22 UTC

This report aggregates precedence detection across multiple JDK versions.

## Summary Table

| JDK | Supported Vars | Unsupported Vars | Precedence (highest→lowest) | Status |
|-----|----------------|------------------|-----------------------------|--------|
| 11 | _JAVA_OPTIONS, JAVA_TOOL_OPTIONS, JDK_JAVA_OPTIONS | (none) | _JAVA_OPTIONS > JDK_JAVA_OPTIONS > JAVA_TOOL_OPTIONS | ok |
| 17 | _JAVA_OPTIONS, JAVA_TOOL_OPTIONS, JDK_JAVA_OPTIONS | (none) | _JAVA_OPTIONS > JDK_JAVA_OPTIONS > JAVA_TOOL_OPTIONS | ok |
| 21 | _JAVA_OPTIONS, JAVA_TOOL_OPTIONS, JDK_JAVA_OPTIONS | (none) | _JAVA_OPTIONS > JDK_JAVA_OPTIONS > JAVA_TOOL_OPTIONS | ok |
| 8 | _JAVA_OPTIONS, JAVA_TOOL_OPTIONS | JDK_JAVA_OPTIONS | _JAVA_OPTIONS > JAVA_TOOL_OPTIONS | ok |

## Support Matrix

Legend: ✅ supported, ❌ unsupported

| JDK | _JAVA_OPTIONS | JAVA_TOOL_OPTIONS | JDK_JAVA_OPTIONS |
|-----|---|---|---|
| 11 | ✅ | ✅ | ✅ |
| 17 | ✅ | ✅ | ✅ |
| 21 | ✅ | ✅ | ✅ |
| 8 | ✅ | ✅ | ❌ |

## Detailed Per-JDK Results

### JDK 11
**Precedence:** `_JAVA_OPTIONS > JDK_JAVA_OPTIONS > JAVA_TOOL_OPTIONS`

<details><summary>Raw JSON</summary>

```json
{"property":"ciProp","supported":["_JAVA_OPTIONS","JAVA_TOOL_OPTIONS","JDK_JAVA_OPTIONS"],"unsupported":[],"pairwise":{"_JAVA_OPTIONS_vs_JAVA_TOOL_OPTIONS":"_JAVA_OPTIONS","_JAVA_OPTIONS_vs_JDK_JAVA_OPTIONS":"_JAVA_OPTIONS","JAVA_TOOL_OPTIONS_vs_JDK_JAVA_OPTIONS":"JDK_JAVA_OPTIONS"},"edges":["_JAVA_OPTIONS>JAVA_TOOL_OPTIONS","_JAVA_OPTIONS>JDK_JAVA_OPTIONS","JDK_JAVA_OPTIONS>JAVA_TOOL_OPTIONS"],"order":["_JAVA_OPTIONS","JDK_JAVA_OPTIONS","JAVA_TOOL_OPTIONS"],"sanity":{"raw":"NOTE: Picked up JDK_JAVA_OPTIONS: -DciProp=from-JDK_JAVA_OPTIONS\nPicked up JAVA_TOOL_OPTIONS: -DciProp=from-JAVA_TOOL_OPTIONS\nPicked up _JAVA_OPTIONS: -DciProp=from-_JAVA_OPTIONS\nciProp=from-_JAVA_OPTIONS","value":"from-_JAVA_OPTIONS"},"status":"ok"}
```
</details>

### JDK 17
**Precedence:** `_JAVA_OPTIONS > JDK_JAVA_OPTIONS > JAVA_TOOL_OPTIONS`

<details><summary>Raw JSON</summary>

```json
{"property":"ciProp","supported":["_JAVA_OPTIONS","JAVA_TOOL_OPTIONS","JDK_JAVA_OPTIONS"],"unsupported":[],"pairwise":{"_JAVA_OPTIONS_vs_JAVA_TOOL_OPTIONS":"_JAVA_OPTIONS","_JAVA_OPTIONS_vs_JDK_JAVA_OPTIONS":"_JAVA_OPTIONS","JAVA_TOOL_OPTIONS_vs_JDK_JAVA_OPTIONS":"JDK_JAVA_OPTIONS"},"edges":["_JAVA_OPTIONS>JAVA_TOOL_OPTIONS","_JAVA_OPTIONS>JDK_JAVA_OPTIONS","JDK_JAVA_OPTIONS>JAVA_TOOL_OPTIONS"],"order":["_JAVA_OPTIONS","JDK_JAVA_OPTIONS","JAVA_TOOL_OPTIONS"],"sanity":{"raw":"NOTE: Picked up JDK_JAVA_OPTIONS: -DciProp=from-JDK_JAVA_OPTIONS\nPicked up JAVA_TOOL_OPTIONS: -DciProp=from-JAVA_TOOL_OPTIONS\nPicked up _JAVA_OPTIONS: -DciProp=from-_JAVA_OPTIONS\nciProp=from-_JAVA_OPTIONS","value":"from-_JAVA_OPTIONS"},"status":"ok"}
```
</details>

### JDK 21
**Precedence:** `_JAVA_OPTIONS > JDK_JAVA_OPTIONS > JAVA_TOOL_OPTIONS`

<details><summary>Raw JSON</summary>

```json
{"property":"ciProp","supported":["_JAVA_OPTIONS","JAVA_TOOL_OPTIONS","JDK_JAVA_OPTIONS"],"unsupported":[],"pairwise":{"_JAVA_OPTIONS_vs_JAVA_TOOL_OPTIONS":"_JAVA_OPTIONS","_JAVA_OPTIONS_vs_JDK_JAVA_OPTIONS":"_JAVA_OPTIONS","JAVA_TOOL_OPTIONS_vs_JDK_JAVA_OPTIONS":"JDK_JAVA_OPTIONS"},"edges":["_JAVA_OPTIONS>JAVA_TOOL_OPTIONS","_JAVA_OPTIONS>JDK_JAVA_OPTIONS","JDK_JAVA_OPTIONS>JAVA_TOOL_OPTIONS"],"order":["_JAVA_OPTIONS","JDK_JAVA_OPTIONS","JAVA_TOOL_OPTIONS"],"sanity":{"raw":"NOTE: Picked up JDK_JAVA_OPTIONS: -DciProp=from-JDK_JAVA_OPTIONS\nPicked up JAVA_TOOL_OPTIONS: -DciProp=from-JAVA_TOOL_OPTIONS\nPicked up _JAVA_OPTIONS: -DciProp=from-_JAVA_OPTIONS\nciProp=from-_JAVA_OPTIONS","value":"from-_JAVA_OPTIONS"},"status":"ok"}
```
</details>

### JDK 8
**Precedence:** `_JAVA_OPTIONS > JAVA_TOOL_OPTIONS`

<details><summary>Raw JSON</summary>

```json
{"property":"ciProp","supported":["_JAVA_OPTIONS","JAVA_TOOL_OPTIONS"],"unsupported":["JDK_JAVA_OPTIONS"],"pairwise":{"_JAVA_OPTIONS_vs_JAVA_TOOL_OPTIONS":"_JAVA_OPTIONS","_JAVA_OPTIONS_vs_JDK_JAVA_OPTIONS":"unsupported","JAVA_TOOL_OPTIONS_vs_JDK_JAVA_OPTIONS":"unsupported"},"edges":["_JAVA_OPTIONS>JAVA_TOOL_OPTIONS","unsupported","unsupported"],"order":["_JAVA_OPTIONS","JAVA_TOOL_OPTIONS"],"sanity":{"raw":"Picked up JAVA_TOOL_OPTIONS: -DciProp=from-JAVA_TOOL_OPTIONS\nPicked up _JAVA_OPTIONS: -DciProp=from-_JAVA_OPTIONS\nciProp=from-_JAVA_OPTIONS","value":"from-_JAVA_OPTIONS"},"status":"ok"}
```
</details>

## Notes

* If a variable is marked unsupported for a JDK (e.g., JDK_JAVA_OPTIONS on JDK 8), comparisons involving it are reported as "unsupported" and it is excluded from the precedence chain.
* Status values: ok (consistent), mismatch (sanity check disagreed), inconclusive (insufficient data or full cycle).
