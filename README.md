# pustakam khaali: starter pack for UNLISTED books

A template for books **anyone with the link can read**, such as books shared on a forum, without using any of your Cloudflare Access seats and without the yaksha.ink name. Each book gets its own repo and its own address, `<name>.pages.dev`.

The book still asks search engines and AI crawlers to stay away, using `robots.txt`, a noindex header and a noindex tag. You can also add a **shared password** for the whole book.

You write Markdown files in `chapters/`. Every save to `main` rebuilds the web book and the EPUB and publishes them.

For books only invited readers can open, use the sister template, `pustakam_taalam`.

---

## Once only

### 1. Make this repo a template

On GitHub, go to this repo's **Settings → General** and tick **Template repository**.

This template repo is public, which is fine: it contains no secrets and no book text. You'll choose the visibility of each book's repo separately.

### 2. A Cloudflare API token

The **Book publisher** token from `pustakam_taalam` works here too. If you'd rather have a separate, smaller token, it needs:

| Type | Permission | Access |
|---|---|---|
| Account | Cloudflare Pages | Edit |
| Account | Account Settings | Read |

Keep it somewhere you can copy it from on your phone.

---

## A new book, from your phone

1. **Create the repo.** Open this repo on GitHub, then **Use this template → Create a new repository**.
   - **Name:** short and lower-case, because it becomes the address. A repo called `river-notes` publishes at `river-notes.pages.dev`. Names are first come, first served across all of Cloudflare; if yours is taken, Cloudflare adds a few letters, and the build summary shows the final link.
   - **Visibility:** **Private** keeps your Markdown source private. **Public** is the free-as-in-freedom choice, but then the whole text is readable on GitHub, so a password on the site would be pointless.
2. **Add the token.** In the new repo, go to **Settings → Secrets and variables → Actions → New repository secret**.
   - Name: `CLOUDFLARE_API_TOKEN`
   - Secret: paste the token.

   (The very first build may already have failed for lack of the token. That's expected.)
3. **Name the book.** Open `_quarto.yml`, tap the pencil, change `title`, `subtitle` and `author`, then **Commit changes**. This starts a build.
4. **Get the link.** Open the **Actions** tab and tap the running build. In 2–3 minutes it goes green, and the summary shows the link.
5. **Write.** Go to `chapters/`, then **Add file → Create new file**. Name it `03-something.md` and start with a `# Chapter title` line. Commit, wait about two minutes, and refresh.

---

## Optional: a shared password

1. In the book's repo, go to **Settings → Secrets and variables → Actions → New repository secret**.
   - Name: `BOOK_PASSWORD`
   - Secret: the password you'll give readers.
2. Go to **Actions → Publish book → Run workflow**, or just commit any change.

Every page then asks for a username and password. **Any username works**; only the password is checked. To change the password, edit the secret and rebuild. To remove it, delete the secret and rebuild.

**Also do this once per password-protected book:** in Cloudflare, go to **Workers & Pages → `<name>` → Settings → Runtime → Fail open/closed** and choose **Fail closed**. The password check runs on Cloudflare's free allowance of 100,000 requests a day, which is several thousand page views. With "fail open", going over that allowance would serve the book without the password; "fail closed" shows an error instead.

**Good to know:** a shared password keeps bots and strangers out, but you can't remove one person; you'd change the password for everyone. Cloudflare's "Block AI bots" switch only works on your own domain, not on `pages.dev`, so the password is the way to keep AI crawlers out completely.

---

## Writing

| To… | Do this |
|---|---|
| Add a chapter | New file in `chapters/` named `NN-title.md`, starting with `# Title` |
| Order chapters | By filename: `01-`, `02-` … `10-`. The list in `_quarto.yml` updates itself |
| Keep a draft out | Start the filename with `draft-`; rename it when it's ready |
| Scene break | A line of `------` with blank lines around it, shown as ✻ ✻ ✻ |
| Italics / bold | `*italics*`, `**bold**` |
| Footnote | `text[^1]`, then `[^1]: the note` on its own line |
| Cite a source | Add it to `chapters/references.bib`, then write `[@key, p. 12]` |
| Typewriter text (plays) | `[like this]{.play}` |
| Tell readers what changed | Add a line to `whats-new.md` |
| Licence, e.g. CC BY-SA | Remove the `#` from the `page-footer` line in `_quarto.yml` |
| Margin comments | See the comments section in `_quarto.yml` |

**Staying anonymous:** the address doesn't link the book to you, but these do: the `author:` line, the GitHub repo (if public) and its commit names. Use a pen name in `author:` if that matters.

**Writing on iOS later:** Working Copy (a Git app) can clone the book's repo, and editors such as Runestone or Textastic can open its files through the Files app. Commit and push from Working Copy, and the build runs the same way.

---

## When something goes wrong

The red ❌ build has a message at the bottom saying what to fix:

| Message | Fix |
|---|---|
| `CLOUDFLARE_API_TOKEN secret is missing` | Step 2 above, then **Re-run jobs** |
| `token is probably missing a permission` | Compare the token's permissions with the table above |
| Red at "Build the book" | A typo in a chapter or `_quarto.yml`; the log line above the error names the file |

## Making it a locked book later

1. Copy `.github/workflows/publish.yml`, `scripts/` and `publishing.yml` from `pustakam_taalam` into the book's repo.
2. Delete `functions/` and `password.js`.
3. Commit.

The address becomes `<name>.yaksha.ink`, and the old `pages.dev` address gets locked too.
