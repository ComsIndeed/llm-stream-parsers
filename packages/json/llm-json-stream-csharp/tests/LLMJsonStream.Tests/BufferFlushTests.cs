using Xunit;

namespace LLMJsonStream.Tests;

public class BufferFlushTests
{
    [Theory(Skip = "TODO: Port buffer_flush_test.dart cases")]
    [InlineData("POTENTIAL BUG: string ending without chunk boundary")]
    [InlineData("number at end of stream without delimiter")]
    [InlineData("multiple values where last one has buffered data")]
    [InlineData("nested property at end with buffered data")]
    [InlineData("stream closes while string buffer has content")]
    [InlineData("verify onChunkEnd is called on stream completion")]
    [InlineData("how many stream chunks are emitted with large input chunk?")]
    [InlineData("track when onChunkEnd is called")]
    public void BufferFlush_Scenarios(string caseName)
    {
    }
}
