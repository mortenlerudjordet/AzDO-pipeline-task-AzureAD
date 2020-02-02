# Azure DevOps Task for AzureAD

# Introduction 

This is a WIP project, though the task is in a working condition.
[It is made possible by building on this version of the Powershell task by Microsoft.](https://github.com/microsoft/azure-pipelines-tasks/tree/master/Tasks/AzurePowerShellV5)

The task is currently using the Powershell module `AzureADPreview`, and powershell code can be written and injected into the task to target the module. It has the same functionality as the builtin Azure Powershell task, though instead of the `Az` module it uses `AzureADPreview` and `MSAL.PS` (authentication) modules.

# Getting Started
## To build this extension on your machine and upload it privately to your AzDO account:

1. Clone this repository
1. Navigate to the directory the repository was cloned into on your machine via Command Prompt
1. Download the latest version of node [here](https://nodejs.org/en/download/)
1. After installing node, close your current Command Prompt window and reopen a new window 
1. You will also need to install the 'TFS Cross Platform Command Line Interface' (tfx-cli) to package your extension. tfx-cli can be installed using npm by running `npm i -g tfx-cli`
1. Sign in to the Visual Studio [Marketplace management portal](https://marketplace.visualstudio.com/manage)
1. If you don't already have a publisher, you will be prompted to create one. All extension live under a publisher
1. Open your extension manifest file: 'vss-extension.json' and set the value of the "publisher" field to the ID of your publisher
1. From the Command Prompt window, run `tfx extension create --rev-version`. This will also increment build number.
1. Running the above command will generate a .vsix file
1. Click the `+ New extension` option and select Visual Studio Team Services
1. Click the link in the center of the Upload dialog to open a browse dialog
1. Locate the .vsix file created in the packaging step and upload it in the dialog box
1. A private version of this extension should now be uploaded to your AzD account

## To test your private extension: 

1. From the management portal, select your newly uploaded extension from the list, right-click, and choose `Share/Unshare`
1. Click the `+ Account button`, enter the name of your account, and press enter
1. After sharing this extension with your AzD account, you must now install it to your account
1. Right-click your extension and choose View Extension to open its details page
1. Click the `Get it free` button to start the installation process (the account you shared the extension with should be selected)
1. Click the `Install` button
1. Your extension should now be installed to your account and ready to use as build and release tasks

# Build and Test
TODO: Describe and show how to build your code and run the tests. 

# Resources
## Links
[Microsoft documentation for building custom tasks](https://docs.microsoft.com/en-us/azure/devops/extend/develop/add-build-task?view=azure-devops)
