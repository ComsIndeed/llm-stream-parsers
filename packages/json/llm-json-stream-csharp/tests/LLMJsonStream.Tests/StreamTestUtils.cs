using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Threading.Tasks;

namespace LLMJsonStream.Tests;

public static class StreamTestUtils
{
    public static async IAsyncEnumerable<string> StreamTextInChunks(
        string text,
        int chunkSize = 10,
        int delayMs = 10,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        for (var i = 0; i < text.Length; i += chunkSize)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var chunk = text.Substring(i, Math.Min(chunkSize, text.Length - i));
            yield return chunk;
            if (i + chunkSize < text.Length && delayMs > 0)
            {
                await Task.Delay(delayMs, cancellationToken);
            }
        }
    }
}
