# GitHub Integration Setup Required

Since the `gh` (GitHub CLI) tool is not installed on your system, the automatic creation of the private repository could not be completed.

Please follow these steps to finish the setup:

1.  **Create a Repository on GitHub:**
    *   Go to [GitHub.com](https://github.com/new).
    *   Create a new repository (e.g., named `FX-Vault`).
    *   Set it to **Private**.
    *   **Do not** initialize with README, .gitignore, or License (keep it empty).

2.  **Link your local vault:**
    Open a terminal (PowerShell) in this folder: `c:\Users\Owner\OneDrive\デスクトップ\FX`
    Run the following commands (replace `YOUR_USERNAME/YOUR_REPO` with your actual details):

    ```powershell
    git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
    git push -u origin master
    ```

3.  **Obsidian Git Plugin:**
    *   The plugin is already configured to **auto-commit and push every 5 minutes**.
    *   Once you link the remote (step 2), it will start working automatically.

4.  **Restart Obsidian:**
    *   I have closed Obsidian for you. Please open it again to load the new settings.
