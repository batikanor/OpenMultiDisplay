# OpenMultiDisplay Website

This is a static website for OpenMultiDisplay. It is intended to deploy as static files from the `website/` directory.

## Local Validation

From the repository root:

```bash
node scripts/validate_website.mjs
```

The validator checks required website files, local asset references, fragment links, CSS `url(...)` references, and `website/vercel.json` JSON syntax.

## Vercel Settings

Recommended Vercel project settings:

| Setting | Value |
| --- | --- |
| Framework Preset | Other |
| Root Directory | `website` |
| Build Command | empty |
| Output Directory | `.` |

The checked-in `website/vercel.json` supports static deployment when the Vercel project root is `website/`.
