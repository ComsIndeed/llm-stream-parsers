using Xunit;

namespace LLMJsonStream.Tests;

public class StreamCompletionTests
{
    [Theory(Skip = "TODO: Port stream_completion_test.dart cases")]
    [InlineData("parser completes when stream closes - single large chunk")]
    [InlineData("parser completes when stream closes - multiple properties")]
    [InlineData("parser completes when stream closes - nested properties")]
    [InlineData("parser handles stream done event properly")]
    [InlineData("string property at end of JSON with large chunk")]
    [InlineData("incremental chunks vs single chunk - same result")]
    [InlineData("string stream emits chunks with small chunk size")]
    [InlineData("string stream behavior with large chunk size")]
    [InlineData("close stream immediately after adding data")]
    [InlineData("close stream with delay after adding data")]
    public void StreamCompletion_Scenarios(string caseName)
    {
        _ = caseName;
    }
}
