# App Vanish website

Plain static site in `public/`, with no build step. It is hosted on Cloudflare Pages at https://appvanish.pages.dev.

Deploy from the repository root:

```sh
npx wrangler pages deploy website/public --project-name appvanish --branch main
```

Pushing to GitHub does not update the site. For a new release, update both download links and the version and size line in `public/index.html`, then deploy.
