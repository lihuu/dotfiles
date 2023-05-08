

### Install gcm by dotnettools
GCM is available to install as a cross-platform .NET tool. This is the preferred install method for Linux because you can use it to install on any .NET-supported distribution. You can also use this method on macOS if you so choose.

Note: Make sure you have installed version 6.0 of the .NET SDK before attempting to run the following dotnet tool commands. After installing, you will also need to follow the output instructions to add the tools directory to your PATH.

Install
```bash
dotnet tool install -g git-credential-manager
git-credential-manager configure
```
Update
```bash
dotnet tool update -g git-credential-manager
```
Uninstall
```bash
git-credential-manager unconfigure
dotnet tool uninstall -g git-credential-manager
```

https://github.com/git-ecosystem/git-credential-manager/blob/release/docs/install.md#net-tool
