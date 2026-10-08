using System.Net;
using System.Text.RegularExpressions;

namespace SearcheXtra.Windows;

public static class BookmarkImport
{
    // Netscape bookmark exports from Edge/Chrome/Firefox/Safari preserve folder nesting.
    public static List<Bookmark> ParseHtml(string html)
    {
        List<Bookmark> root = [];
        var stack = new Stack<List<Bookmark>>();
        stack.Push(root);
        Bookmark? pending = null;
        foreach (Match token in Regex.Matches(html, @"<H3\b[^>]*>(.*?)</H3>|<A\b([^>]*)>(.*?)</A>|<DL\b[^>]*>|</DL\s*>", RegexOptions.IgnoreCase | RegexOptions.Singleline))
        {
            if (token.Value.StartsWith("<H3", StringComparison.OrdinalIgnoreCase))
            {
                pending = new() { Title = Plain(token.Groups[1].Value), Children = [] };
                stack.Peek().Add(pending);
            }
            else if (token.Value.StartsWith("<A", StringComparison.OrdinalIgnoreCase))
            {
                var href = Regex.Match(token.Groups[2].Value, "HREF\\s*=\\s*[\"']([^\"']+)[\"']", RegexOptions.IgnoreCase);
                var url = WebUtility.HtmlDecode(href.Groups[1].Value);
                if (AddressParser.IsWeb(url)) stack.Peek().Add(new() { Title = Plain(token.Groups[3].Value), Url = url });
            }
            else if (token.Value.StartsWith("</DL", StringComparison.OrdinalIgnoreCase)) { if (stack.Count > 1) stack.Pop(); }
            else if (pending != null) { stack.Push(pending.Children!); pending = null; }
        }
        return root;
    }
    private static string Plain(string html) => WebUtility.HtmlDecode(Regex.Replace(html, "<[^>]+>", "")).Trim();
    public static IEnumerable<Bookmark> Flatten(IEnumerable<Bookmark> bookmarks)
    {
        foreach (var node in bookmarks)
        {
            yield return node;
            if (node.Children != null) foreach (var child in Flatten(node.Children)) yield return child;
        }
    }
}
