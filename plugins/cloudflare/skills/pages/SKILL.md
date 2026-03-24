---
name: cloudflare-pages
description: >
  Use this skill when the user asks about Cloudflare Pages, deploying static
  sites or full-stack apps on Cloudflare, JAMstack hosting, or managing Pages
  projects with Pulumi.
---

# Cloudflare Pages

Pages is Cloudflare's full-stack hosting platform for static sites and server-rendered applications. It supports Git-connected deployments, preview URLs per branch, and Pages Functions (Workers under the hood).

- **Docs**: <https://developers.cloudflare.com/pages/>
- **Dashboard**: <https://dash.cloudflare.com/?to=/:account/pages>
- **Pulumi resource**: `cloudflare.PagesProject` ([docs](https://www.pulumi.com/registry/packages/cloudflare/api-docs/pagesproject/))

## Supported Frameworks

Next.js, Astro, Nuxt, SvelteKit, Remix, Gatsby, Hugo, Vite, and any static site generator.

## Deployment Methods

1. **Git integration** — Connect GitHub/GitLab for auto-deploys on push
2. **Direct upload** — `npx wrangler pages deploy ./dist`
3. **CLI** — `npx wrangler pages project create my-site`

## Pages Functions

Add server-side logic by placing files in `functions/`:

```
my-site/
  functions/
    api/
      hello.ts    -> routes to /api/hello
  public/
    index.html
```

```typescript
// functions/api/hello.ts
export const onRequestGet: PagesFunction = async (context) => {
  return new Response("Hello from Pages Functions!");
};
```

## Pulumi IaC

```typescript
import * as cloudflare from "@pulumi/cloudflare";

const project = new cloudflare.PagesProject("my-site", {
  accountId,
  name: "my-site",
  productionBranch: "main",

  source: {
    type: "github",
    config: {
      owner: "nsheaps",
      repoName: "my-site",
      productionBranch: "main",
      deploymentsEnabled: true,
      prCommentsEnabled: true,
      productionDeploymentEnabled: true,
      previewDeploymentSetting: "all",
    },
  },

  buildConfig: {
    buildCommand: "npm run build",
    destinationDir: "dist",
  },
});

// Custom domain
const pagesDomain = new cloudflare.PagesDomain("my-domain", {
  accountId,
  projectName: project.name,
  domain: "my-site.example.com",
});
```

## Pricing

| Feature | Free | Pro |
|---------|------|-----|
| Sites | Unlimited | Unlimited |
| Requests | Unlimited | Unlimited |
| Bandwidth | Unlimited | Unlimited |
| Builds | 500/month | 5,000/month |
| Concurrent builds | 1 | 5 |
| Functions requests | 100K/day | Unlimited |

## References

- [Pages Docs](https://developers.cloudflare.com/pages/)
- [Pages Functions](https://developers.cloudflare.com/pages/functions/)
- [Framework Guides](https://developers.cloudflare.com/pages/framework-guides/)
- [Pulumi PagesProject](https://www.pulumi.com/registry/packages/cloudflare/api-docs/pagesproject/)
