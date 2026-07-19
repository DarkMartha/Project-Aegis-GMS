# Publish Aegis GMS as a public GitHub repository

Keep access tokens private and never commit them to this project.

## Browser method

1. Sign in to GitHub.
2. Select **New repository**.
3. Name it `Aegis-GMS`.
4. Add the description: `A modular, server-authoritative Roblox administration framework written in Luau.`
5. Choose **Public**.
6. Do not initialise it with a README, licence, or `.gitignore`, because those files already exist here.
7. Create the repository.
8. On the empty repository page, choose **uploading an existing file**.
9. Upload the contents of this folder, including the hidden `.github` directory.
10. Commit the files to the `main` branch.
11. Replace `OWNER` in `.github/ISSUE_TEMPLATE/config.yml` with the GitHub account or organisation name.
12. Open **Releases**, choose **Draft a new release**, use tag `v1.0.0`, paste `RELEASE_NOTES_v1.0.0.md`, and attach `AegisGMS_Studio_Package.rbxmx` plus the source ZIP if desired.

Anyone can then download the source using GitHub's **Code → Download ZIP** button or download the Studio package from Releases.

## Git command method

Create an empty public repository on GitHub first, then run:

```bash
git init
git add .
git commit -m "Release Aegis GMS v1.0.0"
git branch -M main
git remote add origin https://github.com/YOUR_ACCOUNT/Aegis-GMS.git
git push -u origin main
```

Authentication should be completed through Git Credential Manager, GitHub CLI, or an SSH key stored on your own computer. Do not paste a token into project files.
