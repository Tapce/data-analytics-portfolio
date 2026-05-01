# Setup Guide — Getting This Onto GitHub

Step-by-step for pushing this folder to a new public GitHub repo. Run these commands from inside the project folder.

## 1. Initialise Git locally

```bash
cd data-analytics-portfolio
git init -b main
git add .
git commit -m "Initial commit: portfolio structure"
```

## 2. Create the repo on GitHub

Go to **github.com → New repository**. Suggested settings:

- **Name:** `data-analytics-portfolio`
- **Description:** *Data analyst portfolio — SQL, Power BI, Tableau projects across supply chain, merchant analytics, and operations.*
- **Visibility:** Public
- **Do NOT** initialise with a README, .gitignore, or license — you already have those locally.

## 3. Connect local to remote

GitHub will show you the exact commands. They look like:

```bash
git remote add origin https://github.com/<your-username>/data-analytics-portfolio.git
git push -u origin main
```

## 4. Polish the repo page

On the GitHub repo page:

- Add **topics** (top right): `data-analytics`, `sql`, `power-bi`, `tableau`, `supply-chain`, `business-intelligence`
- Add a short **About** description
- Add a **website** link (your LinkedIn) in the About section

## 5. Link from LinkedIn

In your LinkedIn **Featured** section, add a link to the GitHub repo with a short title like *"Data Analytics Portfolio — SQL, Power BI, Tableau"*.

## 6. Day-to-day workflow

When you add a new project or change a file:

```bash
git add .
git commit -m "Short description of what changed"
git push
```

---

**One rule:** never commit raw data, credentials, or anything you wouldn't want a recruiter to see. The `.gitignore` covers most of this, but always glance at `git status` before committing.
