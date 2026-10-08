using SearcheXtra.Windows;
using System.Text.Json;
using System.Text;
using System.Security.Cryptography;
using System.IO.Compression;

Environment.SetEnvironmentVariable("SEARCHEXTRA_DATA_DIR", Path.Combine(Path.GetTempPath(), args.Length > 0 && args[0] == "--local-ai-probe" ? "SearcheXtra-local-model-probe" : "SearcheXtra-tests-" + Guid.NewGuid().ToString("N")));
if (args.Length == 2 && args[0] == "--local-ai-probe")
{
    if (!File.Exists(LocalAI.ModelPath)) { Console.WriteLine("Downloading pinned Qwen3 model for isolated inference test…"); await LocalAI.InstallAsync(null); }
    Console.WriteLine("Model verified; starting isolated CPU worker…"); using var cancellation = new CancellationTokenSource(TimeSpan.FromMinutes(5));
    var answer = await LocalAI.AskAsync("Reply using one short sentence.", "What is two plus two? /no_think", cancellation.Token, Path.GetFullPath(args[1]));
    if (!(answer.Contains('4') || answer.Contains("four", StringComparison.OrdinalIgnoreCase))) throw new Exception("Local inference answer: " + answer); LocalAI.Stop(); Console.WriteLine("PASS: verified local CPU inference: " + answer); return;
}
var count = 0;
void Check(bool condition, string message) { if (!condition) throw new Exception(message); count++; }
const string search = "https://www.bing.com/search?q={0}";
Check(AddressParser.Resolve("example.com/path", search).AbsoluteUri == "https://example.com/path", "Bare hostname");
Check(AddressParser.Resolve("localhost:8080/test", search).AbsoluteUri == "http://localhost:8080/test", "Localhost");
Check(AddressParser.Resolve("中文 test & x", search).Query.Contains("%26"), "Search escaping");
Check(!AddressParser.IsWeb("javascript:alert(1)"), "Reject script bookmark");
Check(AddressParser.Resolve("", search).AbsoluteUri == "about:blank", "Blank page");
var imported = BookmarkImport.ParseHtml("<DL><p><DT><H3>Work &amp; tools</H3><DL><p><DT><A HREF=\"https://example.com/?a=1&amp;b=2\">Example</A><DT><H3>Nested</H3><DL><DT><A HREF=\"https://example.org\">Second</A></DL></DL><DT><A HREF=\"javascript:evil()\">Bad</A></DL>");
Check(imported.Count == 1 && imported[0].Title == "Work & tools", "Import folder");
Check(imported[0].Children?.Count == 2, "Import children");
Check(BookmarkImport.Flatten(imported).Count(b => b.Url != null) == 2, "Nested import and unsafe URL filtering");
Check(imported[0].Children![0].Url!.Contains("&b=2"), "HTML URL decoding");
Check(SiteSearch.Match(new(), "yout")?.Name == "YouTube" && SiteSearch.Match(new(), "so")?.Name == "Stack Overflow", "Built-in site search prefixes and aliases");
Check(SiteSearch.Match(new(), "youtube cats") == null && SiteSearch.Match(new(), "y") == null, "Site search needs a name prefix");
var chromeTree = BrowserImport.ChromeBookmarks("""{"roots":{"bookmark_bar":{"name":"Bar","children":[{"name":"Example","url":"https://example.com"},{"name":"Bad","url":"javascript:bad"}]}}}""");
Check(chromeTree.Count == 1 && chromeTree[0].Children?.Count == 1, "Chrome profile bookmarks preserve folders and filter scripts");
var chromeProfile = Path.Combine(DataStore.Root, "ChromeFixture"); Directory.CreateDirectory(chromeProfile);
await using (var database = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=" + Path.Combine(chromeProfile, "History")))
{
    await database.OpenAsync(); using var command = database.CreateCommand(); command.CommandText = "CREATE TABLE urls(url TEXT,title TEXT,last_visit_time INTEGER); INSERT INTO urls VALUES('https://example.com','Imported',13380163200000000);"; await command.ExecuteNonQueryAsync();
}
var browserData = await BrowserImport.ProfileAsync(chromeProfile);
Check(browserData.History.Count == 1 && browserData.History[0].Visited.Year == 2025, "Chrome SQLite history timestamps convert from Windows epoch");
var store = await DataStore.LoadAsync();
store.Settings.CompactBookmarksBar = true;
store.Settings.BookmarkOpening = BookmarkOpening.Background;
store.Bookmarks.AddRange(imported);
store.Session = new() { Tabs = [new("https://example.com", "Restored", true, "Default")], ActiveIndex = 0 };
await store.SaveAsync();
var restored = await DataStore.LoadAsync();
Check(restored.Settings.CompactBookmarksBar && restored.Settings.BookmarkOpening == BookmarkOpening.Background, "Persist bookmark preferences");
Check(restored.Session.Tabs.Count == 1 && restored.Session.Tabs[0].Pinned, "Persist lazy session metadata");
await File.WriteAllTextAsync(Path.Combine(DataStore.Root, "bookmarks.json"), "broken json");
var corrupt = await DataStore.LoadAsync();
Check(corrupt.Bookmarks.Count == 0 && Directory.GetFiles(DataStore.Root, "bookmarks.json.corrupt-*").Length == 1, "Quarantine corrupt data");
Check(!Directory.GetFiles(DataStore.Root, "*.tmp").Any(), "Atomic writes cleaned up");
var csv = CsvPasswords.Parse("name,url,username,password\r\nExample,https://example.com/login,\"a,b\",\"p\"\"w\"\r\nBad,javascript:bad,x,y");
Check(csv.Count == 1 && csv[0].Origin == "https://example.com" && csv[0].Username == "a,b" && csv[0].Password == "p\"w", "CSV quotes and origin filtering");
Check(CrxInstaller.StoreId("https://chromewebstore.google.com/detail/test/aapbdbdomjkkjkaonfhkkikfgjllcleb") == "aapbdbdomjkkjkaonfhkkikfgjllcleb", "Store listing ID");
Check(CrxInstaller.StoreId("https://evil.example/detail/aapbdbdomjkkjkaonfhkkikfgjllcleb") == null, "Store host validation");
static byte[] Varint(uint value) { var bytes = new List<byte>(); do { var b = (byte)(value & 127); value >>= 7; bytes.Add((byte)(b | (value > 0 ? 128 : 0))); } while (value > 0); return bytes.ToArray(); }
static byte[] Field(uint number, byte[] data) => Varint((number << 3) | 2).Concat(Varint((uint)data.Length)).Concat(data).ToArray();
using var rsa = RSA.Create(2048); var key = rsa.ExportSubjectPublicKeyInfo(); var identity = SHA256.HashData(key)[..16]; var id = CrxInstaller.Letters(identity);
using var archiveBytes = new MemoryStream();
using (var archive = new ZipArchive(archiveBytes, ZipArchiveMode.Create, true)) { using var writer = new StreamWriter(archive.CreateEntry("manifest.json").Open()); writer.Write("{\"manifest_version\":3,\"name\":\"Signed fixture\",\"version\":\"1.0\"}"); }
var zip = archiveBytes.ToArray(); var signed = Field(1, identity); var message = Encoding.ASCII.GetBytes("CRX3 SignedData\0").Concat(BitConverter.GetBytes(signed.Length)).Concat(signed).Concat(zip).ToArray();
var signature = rsa.SignData(message, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1); var proof = Field(1, key).Concat(Field(2, signature)).ToArray(); var header = Field(2, proof).Concat(Field(10000, signed)).ToArray();
var crx = Encoding.ASCII.GetBytes("Cr24").Concat(BitConverter.GetBytes(3)).Concat(BitConverter.GetBytes(header.Length)).Concat(header).Concat(zip).ToArray();
Check(CrxInstaller.VerifiedZip(crx, id).SequenceEqual(zip), "CRX3 owner signature verifies");
bool Reject(Action action) { try { action(); return false; } catch (InvalidDataException) { return true; } }
var damaged = crx.ToArray(); damaged[^1] ^= 1;
Check(Reject(() => CrxInstaller.VerifiedZip(damaged, id)), "Tampered CRX3 rejected");
Check(Reject(() => CrxInstaller.VerifiedZip(crx, new string('a', 32))), "Wrong extension ID rejected");
var unpack = Path.Combine(DataStore.Root, "unpack"); CrxInstaller.Unpack(zip, unpack); CrxInstaller.PreserveId(unpack, id, crx);
Check(JsonDocument.Parse(File.ReadAllText(Path.Combine(unpack, "manifest.json"))).RootElement.GetProperty("key").GetString() == Convert.ToBase64String(key), "Unpacked extension preserves Chrome ID");
var crx2Signature = rsa.SignData(zip, HashAlgorithmName.SHA1, RSASignaturePadding.Pkcs1);
var crx2 = Encoding.ASCII.GetBytes("Cr24").Concat(BitConverter.GetBytes(2)).Concat(BitConverter.GetBytes(key.Length)).Concat(BitConverter.GetBytes(crx2Signature.Length)).Concat(key).Concat(crx2Signature).Concat(zip).ToArray();
Check(CrxInstaller.PackageId(crx2) == id && CrxInstaller.PackageId(crx) == id, "CRX2 and CRX3 identity extraction");
Check(CrxInstaller.VerifiedZip(crx2, id).SequenceEqual(zip), "Legacy CRX2 RSA signature verifies");
var badCrx2 = crx2.ToArray(); badCrx2[^1] ^= 1;
Check(Reject(() => CrxInstaller.VerifiedZip(badCrx2, id)), "Tampered CRX2 rejected");
Check(Reject(() => CrxInstaller.VerifiedZip(crx2, new string('a', 32))), "CRX2 wrong identity rejected");
Check(Reject(() => CrxInstaller.VerifiedZip(crx2[..14], id)), "Truncated CRX2 rejected");
var legacyPath = Path.Combine(DataStore.Root, "legacy.crx"); await File.WriteAllBytesAsync(legacyPath, crx2);
var legacyFolder = await CrxInstaller.ImportAsync(legacyPath, Path.Combine(DataStore.Root, "imports"));
Check(JsonDocument.Parse(File.ReadAllText(Path.Combine(legacyFolder, "manifest.json"))).RootElement.GetProperty("key").GetString() == Convert.ToBase64String(key), "Imported CRX2 retains extension identity");
using var nestedZip = new MemoryStream(); using (var archive = new ZipArchive(nestedZip, ZipArchiveMode.Create, true)) { using var writer = new StreamWriter(archive.CreateEntry("old-extension/manifest.json").Open()); writer.Write("{\"manifest_version\":2,\"name\":\"Legacy\",\"version\":\"1.0\"}"); }
var nestedPath = Path.Combine(DataStore.Root, "nested.zip"); await File.WriteAllBytesAsync(nestedPath, nestedZip.ToArray()); var nestedFolder = await CrxInstaller.ImportAsync(nestedPath, Path.Combine(DataStore.Root, "imports"));
Check(JsonDocument.Parse(File.ReadAllText(Path.Combine(nestedFolder, "manifest.json"))).RootElement.GetProperty("manifest_version").GetInt32() == 2, "ZIP import discovers nested original MV2 manifest");
using var unsafeBytes = new MemoryStream(); using (var archive = new ZipArchive(unsafeBytes, ZipArchiveMode.Create, true)) { using var writer = new StreamWriter(archive.CreateEntry("../escape.txt").Open()); writer.Write("bad"); }
Check(Reject(() => CrxInstaller.Unpack(unsafeBytes.ToArray(), Path.Combine(DataStore.Root, "bad"))) && !File.Exists(Path.Combine(DataStore.Root, "escape.txt")), "Archive traversal rejected before writing");
if (args.Length == 2 && args[0] == "--store-probe") { var folder = await CrxInstaller.FetchAsync(args[1], Path.Combine(DataStore.Root, "store")); Console.WriteLine("Verified Chrome store package: " + folder); }
Console.WriteLine($"PASS: {count} checks. Isolated test data: {DataStore.Root}");
