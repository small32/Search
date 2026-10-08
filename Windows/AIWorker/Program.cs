using LLama;
using LLama.Common;
using LLama.Sampling;
using System.Text.Json;

if (args.Length != 1 || !File.Exists(args[0])) { Console.WriteLine("{\"error\":\"Model missing\"}"); return; }
try
{
    var parameters = new ModelParams(args[0]) { ContextSize = 8192, GpuLayerCount = 0, Threads = Math.Clamp(Environment.ProcessorCount / 2, 1, 8) };
    using var weights = await LLamaWeights.LoadFromFileAsync(parameters);
    Console.WriteLine("{\"ready\":true}");
    while (await Console.In.ReadLineAsync() is { } line)
    {
        try
        {
            using var input = JsonDocument.Parse(line); var system = input.RootElement.GetProperty("system").GetString() ?? ""; var prompt = input.RootElement.GetProperty("prompt").GetString() ?? "";
            var executor = new StatelessExecutor(weights, parameters) { ApplyTemplate = true, SystemMessage = system };
            await foreach (var piece in executor.InferAsync(prompt + "\n/no_think", new InferenceParams { MaxTokens = 1024, AntiPrompts = ["<|im_end|>"], SamplingPipeline = new DefaultSamplingPipeline { Temperature = .2f } }))
                Console.WriteLine(JsonSerializer.Serialize(new { piece }));
            Console.WriteLine("{\"done\":true}");
        }
        catch (Exception) { Console.WriteLine("{\"error\":\"Local inference failed\"}"); }
    }
}
catch (Exception) { Console.WriteLine("{\"error\":\"The local model could not be loaded\"}"); }
