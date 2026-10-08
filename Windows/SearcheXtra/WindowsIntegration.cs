using Microsoft.Win32;

namespace SearcheXtra.Windows;

public static class WindowsIntegration
{
    public static void RegisterBrowser()
    {
        var exe = Environment.ProcessPath ?? throw new InvalidOperationException("Executable path missing.");
        using (var protocol = Registry.CurrentUser.CreateSubKey(@"Software\Classes\SearcheXtraURL"))
        { protocol.SetValue("", "SearcheXtra URL"); protocol.SetValue("URL Protocol", ""); using var icon = protocol.CreateSubKey("DefaultIcon"); icon.SetValue("", $"\"{exe}\",0"); using var command = protocol.CreateSubKey(@"shell\open\command"); command.SetValue("", $"\"{exe}\" --url \"%1\""); }
        using (var browser = Registry.CurrentUser.CreateSubKey(@"Software\Clients\StartMenuInternet\SearcheXtra"))
        { browser.SetValue("", "SearcheXtra"); using var capabilities = browser.CreateSubKey("Capabilities"); capabilities.SetValue("ApplicationName", "SearcheXtra"); capabilities.SetValue("ApplicationDescription", "SearcheXtra web browser"); using var urls = capabilities.CreateSubKey("URLAssociations"); urls.SetValue("http", "SearcheXtraURL"); urls.SetValue("https", "SearcheXtraURL"); }
        using var registered = Registry.CurrentUser.CreateSubKey(@"Software\RegisteredApplications"); registered.SetValue("SearcheXtra", @"Software\Clients\StartMenuInternet\SearcheXtra\Capabilities");
    }
}
