# GitHub Setup Instructions

Follow these steps to push your code to GitHub:

## Step 1: Create a new repository on GitHub

1. Go to [GitHub.com](https://github.com) and sign in
2. Click the "+" icon in the top-right corner and select "New repository"
3. Name your repository (e.g., "ExcelDeviceManager")
4. Add a description (optional): "Excel-based device management scripts for Microsoft 365"
5. Choose "Public" or "Private" visibility
6. Do NOT initialize the repository with a README, .gitignore, or license
7. Click "Create repository"

## Step 2: Push your local repository to GitHub

After creating the repository, GitHub will show you commands to push an existing repository. Run these commands in your Scripts directory:

```powershell
# Navigate to your Scripts directory
cd j:\Projects\cursordevin\m365tools\Scripts

# Add the remote repository URL (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/ExcelDeviceManager.git

# Push your code to GitHub
git push -u origin master
```

## Step 3: Verify your repository

1. Refresh your GitHub repository page
2. You should see all your files: README.md, Export-DeviceInventoryForReview.ps1, Process-DeviceReviewDecisions.ps1, and Excel-Based-Device-Management-Guide.md

## Step 4: Clone the repository to test

To test the scripts, you can clone the repository to another location:

```powershell
# Navigate to where you want to clone the repository
cd C:\Path\To\Test\Location

# Clone the repository
git clone https://github.com/YOUR_USERNAME/ExcelDeviceManager.git

# Navigate to the cloned repository
cd ExcelDeviceManager

# Run the scripts (after connecting to required services)
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All","User.Read.All","Group.Read.All"
Connect-AzureAD
.\Export-DeviceInventoryForReview.ps1 -School "Your School Name"
```
